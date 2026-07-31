<#
.SYNOPSIS
    Wires guarded Nexus downloads, remote metadata caching, and update-menu UX.
#>

Set-StrictMode -Version Latest

$script:PwRemoteMetadataCache = @{}
$script:PwRemoteMetadataCacheMinutes = 10

function Get-PwRemoteCredentialFingerprint {

    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Credential
    )

    if ([string]::IsNullOrWhiteSpace($Credential)) {
        return 'anonymous'
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Credential)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    [Convert]::ToHexString($hash).Substring(0, 16)
}

function Clear-PwRemoteMetadataCache {

    [CmdletBinding()]
    param(
        [ValidateSet('All', 'NexusMods', 'GitHub')]
        [string]$Provider = 'All'
    )

    if ($Provider -eq 'All') {
        $script:PwRemoteMetadataCache = @{}
        return
    }

    $prefix = "$Provider|"

    foreach ($key in @($script:PwRemoteMetadataCache.Keys)) {
        if ($key.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            $null = $script:PwRemoteMetadataCache.Remove($key)
        }
    }
}

function Invoke-PwCachedRemoteRequest {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('NexusMods', 'GitHub')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [scriptblock]$Request,

        [AllowEmptyString()]
        [string]$Credential,

        [ValidateRange(1, 1440)]
        [int]$MaxAgeMinutes = $script:PwRemoteMetadataCacheMinutes,

        [switch]$Refresh
    )

    $normalizedPath = $Path.TrimStart('/').ToLowerInvariant()
    $credentialScope = Get-PwRemoteCredentialFingerprint `
        -Credential $Credential
    $key = "$Provider|$credentialScope|$normalizedPath"
    $now = (Get-Date).ToUniversalTime()

    if (
        -not $Refresh -and
        $script:PwRemoteMetadataCache.ContainsKey($key)
    ) {
        $entry = $script:PwRemoteMetadataCache[$key]
        $age = $now - ([datetime]$entry.RetrievedAt).ToUniversalTime()

        if ($age.TotalMinutes -lt $MaxAgeMinutes) {
            Write-Output -NoEnumerate $entry.Value
            return
        }

        $null = $script:PwRemoteMetadataCache.Remove($key)
    }

    $value = & $Request
    $script:PwRemoteMetadataCache[$key] = [PSCustomObject]@{
        Provider = $Provider
        Path = $normalizedPath
        RetrievedAt = $now
        Value = $value
    }

    Write-Output -NoEnumerate $value
}

function Invoke-PwNexusApi {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$ApiKey,

        [switch]$Refresh
    )

    $resolvedKey = Resolve-PwNexusApiKey -ApiKey $ApiKey
    $normalizedPath = $Path.TrimStart('/')
    $uri = 'https://api.nexusmods.com/v1/' + $normalizedPath
    $headers = @{
        apikey = $resolvedKey
        'Application-Name' = 'Palworld-Modding-Workshop'
        'Application-Version' = (Get-PwVersion)
    }
    $request = {
        Invoke-RestMethod `
            -Method Get `
            -Uri $uri `
            -Headers $headers `
            -UserAgent 'Palworld-Modding-Workshop'
    }

    if ($normalizedPath -match '(?i)/download_link\.json$') {
        return & $request
    }

    Invoke-PwCachedRemoteRequest `
        -Provider NexusMods `
        -Path $normalizedPath `
        -Credential $resolvedKey `
        -Refresh:$Refresh `
        -Request $request
}

function Invoke-PwGitHubApi {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Refresh
    )

    $normalizedPath = $Path.TrimStart('/')
    $headers = @{
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent' = 'Palworld-Modding-Workshop'
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)"
    }

    $request = {
        Invoke-RestMethod `
            -Uri "https://api.github.com/$normalizedPath" `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop
    }

    Invoke-PwCachedRemoteRequest `
        -Provider GitHub `
        -Path $normalizedPath `
        -Credential ([string]$env:GITHUB_TOKEN) `
        -Refresh:$Refresh `
        -Request $request
}

$script:PwReadWorkshopPagedTableCore = ${function:Read-PwWorkshopPagedTable}

function Read-PwWorkshopPagedTable {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [object[]]$Rows = @(),

        [Parameter(Mandatory)]
        [object[]]$Properties,

        [Parameter(Mandatory)]
        [string]$Prompt,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Page = 1
    )

    $isUpdatesPrompt = $Prompt.StartsWith(
        'Nexus mod ID,',
        [System.StringComparison]::Ordinal
    )
    $effectivePrompt = if ($isUpdatesPrompt) {
        'Nexus mod ID, [U] record UE4SS baseline, [R] Refresh, ' +
            '[B] Back, Enter to return, or Q to quit'
    }
    else {
        $Prompt
    }
    $selection = & $script:PwReadWorkshopPagedTableCore `
        -Title $Title `
        -Rows $Rows `
        -Properties $Properties `
        -Prompt $effectivePrompt `
        -Page $Page

    if (-not $isUpdatesPrompt) {
        return $selection
    }

    if (Test-PwWorkshopBackSelection $selection) {
        return ''
    }

    if ($selection -match '^(?i:R)$') {
        Clear-PwRemoteMetadataCache
        Write-Host (
            'Remote metadata cache cleared. Refreshing Nexus and GitHub ' +
                'update information.'
        ) -ForegroundColor DarkGray
    }

    $selection
}

function Open-PwNexusModPage {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [switch]$Launch
    )

    $url = "https://www.nexusmods.com/palworld/mods/${ModId}?tab=files"

    if ($Launch -and $PSCmdlet.ShouldProcess($url, 'Open Nexus Mods page')) {
        $archiveRoot = [System.IO.Path]::GetFullPath((Get-PwPaths).Archives)

        Write-Host ''
        Write-Host 'Manual Nexus Download' -ForegroundColor Cyan
        Write-Host 'Save the completed ZIP or 7z file directly into:'
        Write-Host "  $archiveRoot" -ForegroundColor Green
        Write-Host (
            'The workshop does not monitor browser download completion. ' +
                'After the file finishes downloading, return to menu 4 and ' +
                'press R to rescan 01_Archives and refresh remote metadata.'
        ) -ForegroundColor Yellow
        Write-Host (
            'Use menu option 2 afterward to inspect and import the archive.'
        ) -ForegroundColor DarkGray

        Start-Process $url
    }

    $url
}

function Save-PwNexusModUpdateCore {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$FileId,

        [string]$ApiKey,

        [string]$Destination = (Get-PwPaths).Archives
    )

    $identity = Get-PwNexusApiIdentity -ApiKey $ApiKey

    if (-not $identity.is_premium) {
        throw (
            'Direct API downloads require Nexus Premium. Use ' +
            "Open-PwNexusModPage -ModId $ModId -Launch for manual download."
        )
    }

    $mod = Invoke-PwNexusApi `
        -Path "games/palworld/mods/$ModId.json" `
        -ApiKey $ApiKey
    $file = Invoke-PwNexusApi `
        -Path "games/palworld/mods/$ModId/files/$FileId.json" `
        -ApiKey $ApiKey
    $links = @(
        Invoke-PwNexusApi `
            -Path (
                "games/palworld/mods/$ModId/files/$FileId/" +
                    'download_link.json'
            ) `
            -ApiKey $ApiKey
    )

    if ($links.Count -eq 0 -or -not $links[0].URI) {
        throw 'Nexus did not return a direct download link.'
    }

    $extension = [System.IO.Path]::GetExtension([string]$file.file_name)

    if ($extension -notin @('.zip', '.7z')) {
        throw "Unsupported Nexus archive format: $extension"
    }

    $safeName = ([string]$mod.name -replace '[<>:"/\\|?*]', '_').Trim()
    $version = ([string]$file.version -replace '\s+', '_').Trim()

    if ([string]::IsNullOrWhiteSpace($safeName)) {
        $safeName = "NexusMod-$ModId"
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = 'unknown'
    }

    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH-mmZ')
    $fileName = "$safeName $ModId $version $timestamp Api$FileId$extension"
    $destinationRoot = [System.IO.Path]::GetFullPath($Destination)
    $destinationPath = Join-Path $destinationRoot $fileName

    if (Test-Path -LiteralPath $destinationPath) {
        throw "Archive already exists: $destinationPath"
    }

    if (-not $PSCmdlet.ShouldProcess(
        $destinationPath,
        "Download Nexus mod $ModId file $FileId"
    )) {
        return [PSCustomObject]@{
            Downloaded = $false
            Path = $destinationPath
            ModId = $ModId
            FileId = $FileId
        }
    }

    New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
    $temporaryPath = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        ([System.IO.Path]::GetRandomFileName() + $extension)

    try {
        Save-PwRemoteFile -Uri ([uri]$links[0].URI) -Path $temporaryPath
        $inspection = Get-PwModArchiveInfo -Path $temporaryPath

        if (-not $inspection.IsSafe) {
            throw 'Downloaded archive failed workshop safety inspection.'
        }

        Move-Item -LiteralPath $temporaryPath -Destination $destinationPath
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }

    [PSCustomObject]@{
        Downloaded = $true
        Path = $destinationPath
        ModId = $ModId
        FileId = $FileId
        Version = $version
        Hash = (
            Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
        ).Hash
    }
}

<#
.SYNOPSIS
    Downloads a selected Nexus file with guarded workshop-menu behavior.
.DESCRIPTION
    Calls from the update menu are matched back to the current update report,
    displayed with exact version, variant, filename, and file ID information,
    and require high-impact confirmation. Non-actionable report rows are
    refused. Other existing explicit-ID callers retain the low-level behavior.
#>
function Save-PwNexusModUpdate {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$FileId,

        [string]$ApiKey,

        [string]$Destination = (Get-PwPaths).Archives
    )

    $fromWorkshopMenu = @(
        Get-PSCallStack |
            Where-Object FunctionName -eq 'Start-PwWorkshop'
    ).Count -gt 0

    if (-not $fromWorkshopMenu) {
        Save-PwNexusModUpdateCore `
            -ModId $ModId `
            -FileId $FileId `
            -ApiKey $ApiKey `
            -Destination $Destination
        return
    }

    Clear-PwRemoteMetadataCache -Provider NexusMods
    $reportRows = @(
        Get-PwModUpdateReport -ApiKey $ApiKey -ModId @($ModId)
    )

    if ($reportRows.Count -eq 0) {
        throw (
            "The refreshed Nexus update report returned no row for mod $ModId. " +
                'Direct menu download is blocked; refresh the update screen or ' +
                'use manual browser download.'
        )
    }

    $selected = $reportRows |
        Where-Object {
            $_.NexusModId -eq $ModId -and
            $_.RemoteFileId -eq $FileId
        } |
        Select-Object -First 1

    if (-not $selected) {
        $current = $reportRows |
            Where-Object NexusModId -eq $ModId |
            Select-Object -First 1

        if ($current) {
            $decision = Get-PwNexusUpdateDownloadDecision -Update $current

            if (-not $decision.CanDownload) {
                throw $decision.Reason
            }

            throw (
                "Nexus file ID $FileId is stale. The current update report " +
                    "selects file ID $($decision.RemoteFileId). Refresh the " +
                    'update screen before downloading.'
            )
        }

        throw "Nexus mod $ModId is not present in the current update report."
    }

    $decision = Get-PwNexusUpdateDownloadDecision -Update $selected

    if (-not $decision.CanDownload) {
        throw $decision.Reason
    }

    Write-Host ''
    Write-Host 'Nexus Update Download' -ForegroundColor Cyan
    $decision |
        Select-Object `
            Name,
            NexusModId,
            LocalVersion,
            RemoteVersion,
            LocalVariant,
            RemoteVariant,
            RemoteFileName,
            RemoteFileId,
            Status |
        Format-List |
        Out-String |
        Write-Host
    Write-Host (
        'The archive will be downloaded temporarily, inspected, and moved ' +
            'into 01_Archives only after validation succeeds.'
    ) -ForegroundColor Yellow

    $target = if (
        [string]::IsNullOrWhiteSpace($decision.RemoteFileName)
    ) {
        "Nexus mod $ModId file $FileId"
    }
    else {
        $decision.RemoteFileName
    }
    $action = (
        "Download $($decision.Name) $($decision.RemoteVersion), validate it, " +
            'and add it to 01_Archives'
    )

    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return [PSCustomObject]@{
            Name = $decision.Name
            NexusModId = $decision.NexusModId
            FileId = $decision.RemoteFileId
            LocalVersion = $decision.LocalVersion
            RemoteVersion = $decision.RemoteVersion
            RemoteFileName = $decision.RemoteFileName
            Downloaded = $false
            Path = ''
            Hash = ''
            NextStep = 'Inspect and import the archive through menu option 2.'
        }
    }

    $result = Save-PwModUpdateFromReport `
        -Update $selected `
        -ApiKey $ApiKey `
        -Destination $Destination `
        -Confirm:$false

    Write-Host ''
    $result |
        Select-Object `
            Name,
            LocalVersion,
            RemoteVersion,
            RemoteFileName,
            Path,
            Hash,
            NextStep |
        Format-List |
        Out-String |
        Write-Host

    $result
}

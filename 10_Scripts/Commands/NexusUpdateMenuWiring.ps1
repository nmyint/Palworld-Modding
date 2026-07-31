<#
.SYNOPSIS
    Wires the workshop menu's Nexus download action to the guarded report flow.
#>

Set-StrictMode -Version Latest

function Save-PwNexusModUpdateCore {

    [CmdletBinding()]
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
        return Save-PwNexusModUpdateCore `
            -ModId $ModId `
            -FileId $FileId `
            -ApiKey $ApiKey `
            -Destination $Destination
    }

    $reportRows = @(
        Get-PwModUpdateReport -ApiKey $ApiKey -ModId @($ModId)
    )

    if ($reportRows.Count -eq 0) {
        return Save-PwNexusModUpdateCore `
            -ModId $ModId `
            -FileId $FileId `
            -ApiKey $ApiKey `
            -Destination $Destination
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

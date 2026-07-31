<#
.SYNOPSIS
    Wires guarded Nexus downloads, persistent metadata caching, and menu UX.
#>

Set-StrictMode -Version Latest

$script:PwNexusMetadataCacheSchemaVersion = '1.0'
$script:PwNexusGameDomain = 'palworld'
$script:PwGitHubMetadataCache = @{}
$script:PwGitHubMetadataCacheMinutes = 10

function Get-PwNexusMetadataCachePath {

    [CmdletBinding()]
    param()

    Join-Path (Get-PwWorkshopRoot) '.cache\NexusMetadata.json'
}

function New-PwEmptyNexusMetadataCache {

    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        SchemaVersion = $script:PwNexusMetadataCacheSchemaVersion
        GameDomain = $script:PwNexusGameDomain
        CreatedAt = $null
        UpdatedAt = $null
        LastFullRefreshAt = $null
        CatalogModIds = @()
        Mods = @()
    }
}

function Read-PwNexusMetadataCache {

    [CmdletBinding()]
    param(
        [string]$Path = (Get-PwNexusMetadataCachePath)
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return New-PwEmptyNexusMetadataCache
    }

    $cache = Read-PwJson -Path $Path

    if (
        -not $cache.PSObject.Properties['SchemaVersion'] -or
        [string]$cache.SchemaVersion -ne
            $script:PwNexusMetadataCacheSchemaVersion
    ) {
        throw (
            'Unsupported Nexus metadata cache schema: ' +
                "$($cache.SchemaVersion)"
        )
    }

    if (
        -not $cache.PSObject.Properties['GameDomain'] -or
        [string]$cache.GameDomain -ne $script:PwNexusGameDomain
    ) {
        throw (
            'Nexus metadata cache is for an unexpected game domain: ' +
                "$($cache.GameDomain)"
        )
    }

    foreach ($property in @(
        'CreatedAt',
        'UpdatedAt',
        'LastFullRefreshAt'
    )) {
        if (-not $cache.PSObject.Properties[$property]) {
            $cache |
                Add-Member `
                    -NotePropertyName $property `
                    -NotePropertyValue $null
        }
    }

    if (-not $cache.PSObject.Properties['CatalogModIds']) {
        $cache |
            Add-Member `
                -NotePropertyName CatalogModIds `
                -NotePropertyValue @()
    }

    if (-not $cache.PSObject.Properties['Mods']) {
        $cache |
            Add-Member `
                -NotePropertyName Mods `
                -NotePropertyValue @()
    }

    $cache
}

function Write-PwNexusMetadataCache {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Cache,

        [string]$Path = (Get-PwNexusMetadataCachePath)
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Write-PwJson -InputObject $Cache -Path $Path -Depth 100
}

function Get-PwCatalogNexusModIds {

    [CmdletBinding()]
    param()

    $ids = [System.Collections.Generic.List[int]]::new()
    $catalog = Get-PwPersistentModCatalog

    foreach ($record in @($catalog.Mods)) {
        if (
            $null -eq $record -or
            -not $record.PSObject.Properties['NexusModIds']
        ) {
            continue
        }

        foreach ($value in @($record.NexusModIds)) {
            if (
                $null -ne $value -and
                [string]$value -match '^\d+$' -and
                [int]$value -gt 0
            ) {
                $ids.Add([int]$value)
            }
        }
    }

    try {
        foreach ($archive in @(
            Get-PwNexusArchiveMetadata -SkipContentInspection
        )) {
            if (
                $null -ne $archive -and
                $archive.PSObject.Properties['NexusModId'] -and
                [string]$archive.NexusModId -match '^\d+$' -and
                [int]$archive.NexusModId -gt 0
            ) {
                $ids.Add([int]$archive.NexusModId)
            }
        }
    }
    catch {
        # The persistent catalog remains authoritative when archives are absent.
    }

    try {
        foreach ($source in @(Get-PwUpdateSources)) {
            if (
                $null -ne $source -and
                [string]$source.Provider -eq 'NexusMods' -and
                $source.PSObject.Properties['NexusModId'] -and
                [string]$source.NexusModId -match '^\d+$' -and
                [int]$source.NexusModId -gt 0
            ) {
                $ids.Add([int]$source.NexusModId)
            }
        }
    }
    catch {
        # Optional source configuration must not block catalog caching.
    }

    @($ids | Sort-Object -Unique)
}

function Get-PwNexusResponseFiles {

    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Response
    )

    if ($null -eq $Response) {
        return @()
    }

    if ($Response.PSObject.Properties['files']) {
        return @($Response.files)
    }

    @($Response)
}

function Invoke-PwNexusApiRequest {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$ApiKey
    )

    $resolvedKey = Resolve-PwNexusApiKey -ApiKey $ApiKey
    $normalizedPath = $Path.TrimStart('/')
    $uri = 'https://api.nexusmods.com/v1/' + $normalizedPath
    $headers = @{
        apikey = $resolvedKey
        'Application-Name' = 'Palworld-Modding-Workshop'
        'Application-Version' = (Get-PwVersion)
    }

    Invoke-RestMethod `
        -Method Get `
        -Uri $uri `
        -Headers $headers `
        -UserAgent 'Palworld-Modding-Workshop' `
        -ErrorAction Stop
}

function Update-PwNexusMetadataCache {

    [CmdletBinding()]
    param(
        [int[]]$ModId,

        [string]$ApiKey,

        [switch]$Refresh,

        [string]$Path = (Get-PwNexusMetadataCachePath)
    )

    $catalogIds = @(Get-PwCatalogNexusModIds)
    $requestedIds = @(
        $ModId |
            Where-Object { $_ -gt 0 } |
            Sort-Object -Unique
    )
    $coverageIds = @(
        @($catalogIds) + @($requestedIds) |
            Sort-Object -Unique
    )
    $cache = Read-PwNexusMetadataCache -Path $Path
    $existingById = @{}

    foreach ($entry in @($cache.Mods)) {
        if (
            $null -ne $entry -and
            $entry.PSObject.Properties['NexusModId'] -and
            [string]$entry.NexusModId -match '^\d+$'
        ) {
            $existingById[[int]$entry.NexusModId] = $entry
        }
    }

    $targetIds = if ($Refresh) {
        if ($requestedIds.Count -gt 0) {
            @($requestedIds)
        }
        else {
            @($coverageIds)
        }
    }
    elseif (@($cache.Mods).Count -eq 0) {
        @($coverageIds)
    }
    else {
        @(
            $coverageIds |
                Where-Object {
                    -not $existingById.ContainsKey([int]$_)
                }
        )
    }
    $now = (Get-Date).ToUniversalTime()
    $nowText = $now.ToString('o')
    $changed = $false

    foreach ($id in $targetIds) {
        $prior = if ($existingById.ContainsKey([int]$id)) {
            $existingById[[int]$id]
        }
        else {
            $null
        }

        try {
            $mod = Invoke-PwNexusApiRequest `
                -Path "games/$($script:PwNexusGameDomain)/mods/$id.json" `
                -ApiKey $ApiKey
            $files = Invoke-PwNexusApiRequest `
                -Path (
                    "games/$($script:PwNexusGameDomain)/mods/$id/files.json"
                ) `
                -ApiKey $ApiKey
            $existingById[[int]$id] = [PSCustomObject]@{
                NexusModId = [int]$id
                RetrievedAt = $nowText
                Status = 'Ready'
                LastRefreshError = ''
                LastRefreshErrorAt = $null
                Mod = $mod
                Files = $files
            }
        }
        catch {
            if (
                $null -ne $prior -and
                $prior.PSObject.Properties['Status'] -and
                [string]$prior.Status -eq 'Ready'
            ) {
                $copy = [ordered]@{}

                foreach ($property in $prior.PSObject.Properties) {
                    $copy[$property.Name] = $property.Value
                }

                $copy.LastRefreshError = $_.Exception.Message
                $copy.LastRefreshErrorAt = $nowText
                $existingById[[int]$id] = [PSCustomObject]$copy
            }
            else {
                $existingById[[int]$id] = [PSCustomObject]@{
                    NexusModId = [int]$id
                    RetrievedAt = $nowText
                    Status = 'Error'
                    LastRefreshError = $_.Exception.Message
                    LastRefreshErrorAt = $nowText
                    Mod = $null
                    Files = $null
                }
            }
        }

        $changed = $true
    }

    $retained = [System.Collections.Generic.List[object]]::new()

    foreach ($id in $coverageIds) {
        if ($existingById.ContainsKey([int]$id)) {
            $retained.Add($existingById[[int]$id])
        }
    }

    $priorCatalogIds = @(
        @($cache.CatalogModIds) |
            Where-Object {
                $null -ne $_ -and [string]$_ -match '^\d+$'
            } |
            ForEach-Object { [int]$_ } |
            Sort-Object -Unique
    )
    $catalogChanged = (
        ($priorCatalogIds -join ',') -ne
        (@($catalogIds) -join ',')
    )
    $entryCountChanged = @($cache.Mods).Count -ne $retained.Count

    if ($catalogChanged -or $entryCountChanged) {
        $changed = $true
    }

    if ($changed) {
        if ($null -eq $cache.CreatedAt) {
            $cache.CreatedAt = $nowText
        }

        $cache.UpdatedAt = $nowText
        $cache.CatalogModIds = @($catalogIds)
        $cache.Mods = @($retained | Sort-Object NexusModId)

        if (
            ($Refresh -and $requestedIds.Count -eq 0) -or
            (
                -not $Refresh -and
                @($cache.Mods).Count -gt 0 -and
                $targetIds.Count -eq $coverageIds.Count
            )
        ) {
            $cache.LastFullRefreshAt = $nowText
        }

        Write-PwNexusMetadataCache -Cache $cache -Path $Path
    }

    $cache
}

function Get-PwNexusMetadataEntry {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [string]$ApiKey,

        [switch]$Refresh
    )

    $cache = Update-PwNexusMetadataCache `
        -ModId @($ModId) `
        -ApiKey $ApiKey `
        -Refresh:$Refresh
    $entry = @(
        $cache.Mods |
            Where-Object NexusModId -eq $ModId
    ) | Select-Object -First 1

    if ($null -eq $entry) {
        throw "Nexus metadata cache has no entry for mod $ModId."
    }

    if (
        -not $entry.PSObject.Properties['Status'] -or
        [string]$entry.Status -ne 'Ready'
    ) {
        $message = if (
            $entry.PSObject.Properties['LastRefreshError'] -and
            -not [string]::IsNullOrWhiteSpace(
                [string]$entry.LastRefreshError
            )
        ) {
            [string]$entry.LastRefreshError
        }
        else {
            "Nexus metadata is unavailable for mod $ModId."
        }

        throw $message
    }

    $entry
}

function Get-PwNexusMetadataCacheInfo {

    [CmdletBinding()]
    param(
        [string]$Path = (Get-PwNexusMetadataCachePath)
    )

    $exists = Test-Path -LiteralPath $Path -PathType Leaf
    $cache = Read-PwNexusMetadataCache -Path $Path
    $entries = @($cache.Mods)
    $ready = @($entries | Where-Object Status -eq 'Ready')
    $errors = @($entries | Where-Object Status -ne 'Ready')
    $catalogIds = @(Get-PwCatalogNexusModIds)
    $cachedIds = @(
        $entries |
            ForEach-Object { [int]$_.NexusModId } |
            Sort-Object -Unique
    )
    $isComplete = (
        $catalogIds.Count -eq $cachedIds.Count -and
        ($catalogIds -join ',') -eq ($cachedIds -join ',') -and
        $errors.Count -eq 0
    )

    [PSCustomObject]@{
        Path = [System.IO.Path]::GetFullPath($Path)
        Exists = $exists
        CreatedAt = $cache.CreatedAt
        UpdatedAt = $cache.UpdatedAt
        LastFullRefreshAt = $cache.LastFullRefreshAt
        CatalogModCount = $catalogIds.Count
        CachedModCount = $entries.Count
        ReadyModCount = $ready.Count
        ErrorModCount = $errors.Count
        IsComplete = $isComplete
    }
}

function Find-PwNexusCachedFile {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Entry,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$FileId
    )

    @(
        Get-PwNexusResponseFiles -Response $Entry.Files |
            Where-Object {
                $_.PSObject.Properties['file_id'] -and
                [int]$_.file_id -eq $FileId
            }
    ) | Select-Object -First 1
}

function Invoke-PwNexusApi {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$ApiKey,

        [switch]$Refresh
    )

    $normalizedPath = $Path.TrimStart('/')

    if ($normalizedPath -match '(?i)/download_link\.json$') {
        return Invoke-PwNexusApiRequest `
            -Path $normalizedPath `
            -ApiKey $ApiKey
    }

    if ($normalizedPath -match '^(?i)users/validate\.json$') {
        return Invoke-PwNexusApiRequest `
            -Path $normalizedPath `
            -ApiKey $ApiKey
    }

    if (
        $normalizedPath -match (
            '^(?i)games/palworld/mods/(?<mod>\d+)/files/' +
                '(?<file>\d+)\.json$'
        )
    ) {
        $modId = [int]$Matches['mod']
        $fileId = [int]$Matches['file']
        $entry = Get-PwNexusMetadataEntry `
            -ModId $modId `
            -ApiKey $ApiKey `
            -Refresh:$Refresh
        $file = Find-PwNexusCachedFile -Entry $entry -FileId $fileId

        if ($null -eq $file -and -not $Refresh) {
            $entry = Get-PwNexusMetadataEntry `
                -ModId $modId `
                -ApiKey $ApiKey `
                -Refresh
            $file = Find-PwNexusCachedFile -Entry $entry -FileId $fileId
        }

        if ($null -eq $file) {
            throw (
                "Nexus file $fileId is not present in the cached file list " +
                    "for mod $modId."
            )
        }

        return $file
    }

    if (
        $normalizedPath -match (
            '^(?i)games/palworld/mods/(?<mod>\d+)/files\.json$'
        )
    ) {
        $entry = Get-PwNexusMetadataEntry `
            -ModId ([int]$Matches['mod']) `
            -ApiKey $ApiKey `
            -Refresh:$Refresh
        return $entry.Files
    }

    if (
        $normalizedPath -match (
            '^(?i)games/palworld/mods/(?<mod>\d+)\.json$'
        )
    ) {
        $entry = Get-PwNexusMetadataEntry `
            -ModId ([int]$Matches['mod']) `
            -ApiKey $ApiKey `
            -Refresh:$Refresh
        return $entry.Mod
    }

    Invoke-PwNexusApiRequest -Path $normalizedPath -ApiKey $ApiKey
}

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

function Clear-PwGitHubMetadataCache {

    [CmdletBinding()]
    param()

    $script:PwGitHubMetadataCache = @{}
}

function Clear-PwRemoteMetadataCache {

    [CmdletBinding()]
    param(
        [ValidateSet('All', 'NexusMods', 'GitHub')]
        [string]$Provider = 'All'
    )

    if ($Provider -in @('All', 'NexusMods')) {
        $path = Get-PwNexusMetadataCachePath
        Remove-Item `
            -LiteralPath $path `
            -Force `
            -ErrorAction SilentlyContinue
    }

    if ($Provider -in @('All', 'GitHub')) {
        Clear-PwGitHubMetadataCache
    }
}

function Invoke-PwCachedGitHubRequest {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [scriptblock]$Request,

        [AllowEmptyString()]
        [string]$Credential,

        [switch]$Refresh
    )

    $normalizedPath = $Path.TrimStart('/').ToLowerInvariant()
    $credentialScope = Get-PwRemoteCredentialFingerprint `
        -Credential $Credential
    $key = "$credentialScope|$normalizedPath"
    $now = (Get-Date).ToUniversalTime()

    if (
        -not $Refresh -and
        $script:PwGitHubMetadataCache.ContainsKey($key)
    ) {
        $entry = $script:PwGitHubMetadataCache[$key]
        $age = $now - ([datetime]$entry.RetrievedAt).ToUniversalTime()

        if ($age.TotalMinutes -lt $script:PwGitHubMetadataCacheMinutes) {
            Write-Output -NoEnumerate $entry.Value
            return
        }

        $null = $script:PwGitHubMetadataCache.Remove($key)
    }

    $value = & $Request
    $script:PwGitHubMetadataCache[$key] = [PSCustomObject]@{
        Path = $normalizedPath
        RetrievedAt = $now
        Value = $value
    }

    Write-Output -NoEnumerate $value
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

    Invoke-PwCachedGitHubRequest `
        -Path $normalizedPath `
        -Credential ([string]$env:GITHUB_TOKEN) `
        -Refresh:$Refresh `
        -Request $request
}

function Get-PwNexusCacheTitleSuffix {

    [CmdletBinding()]
    param()

    $info = Get-PwNexusMetadataCacheInfo
    $timestampValue = if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$info.LastFullRefreshAt
        )
    ) {
        [string]$info.LastFullRefreshAt
    }
    else {
        [string]$info.UpdatedAt
    }
    $timestamp = if ([string]::IsNullOrWhiteSpace($timestampValue)) {
        'not built'
    }
    else {
        ([datetime]$timestampValue).ToUniversalTime().ToString(
            'yyyy-MM-dd HH:mm:ss ''UTC'''
        )
    }

    "Nexus cache: $timestamp | $($info.ReadyModCount)/" +
        "$($info.CatalogModCount) mods"
}

$script:PwInvokeWorkshopMenuActionCore = ${function:Invoke-PwWorkshopMenuAction}

function Invoke-PwWorkshopMenuAction {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'Summary',
            'Catalog',
            'CatalogPlan',
            'CatalogMetadata',
            'StagingReconciliation',
            'Archives',
            'Staging',
            'Updates',
            'SourceUpdates',
            'Diagnostics',
            'Inventory',
            'History'
        )]
        [string]$Action
    )

    if ($Action -in @('CatalogMetadata', 'Updates')) {
        Update-PwNexusMetadataCache | Out-Null
    }

    & $script:PwInvokeWorkshopMenuActionCore -Action $Action
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
    $isCatalogMetadata = $Title -eq 'Remote Catalog Metadata'
    $currentRows = @($Rows)

    while ($true) {
        $effectiveTitle = if ($isUpdatesPrompt -or $isCatalogMetadata) {
            "$Title | $(Get-PwNexusCacheTitleSuffix)"
        }
        else {
            $Title
        }
        $effectivePrompt = if ($isUpdatesPrompt) {
            'Nexus mod ID, [U] record UE4SS baseline, [R] Refresh, ' +
                '[B] Back, Enter to return, or Q to quit'
        }
        elseif ($isCatalogMetadata) {
            '[A] Store metadata, [V] Verify review item, ' +
                '[R] Refresh Nexus cache, [B] Back, or Q to quit'
        }
        else {
            $Prompt
        }
        $selection = & $script:PwReadWorkshopPagedTableCore `
            -Title $effectiveTitle `
            -Rows $currentRows `
            -Properties $Properties `
            -Prompt $effectivePrompt `
            -Page $Page

        if ($selection -match '^(?i:R)$' -and $isUpdatesPrompt) {
            Update-PwNexusMetadataCache -Refresh | Out-Null
            Clear-PwGitHubMetadataCache
            Write-Host (
                'Nexus catalog metadata and GitHub source metadata were ' +
                    'refreshed.'
            ) -ForegroundColor DarkGray
            return 'R'
        }

        if ($selection -match '^(?i:R)$' -and $isCatalogMetadata) {
            Update-PwNexusMetadataCache -Refresh | Out-Null
            $currentRows = @(Get-PwNexusCatalogMetadataReport)
            Write-Host (
                'Nexus catalog metadata was refreshed from the API.'
            ) -ForegroundColor DarkGray
            continue
        }

        if (
            $isUpdatesPrompt -and
            (Test-PwWorkshopBackSelection $selection)
        ) {
            return ''
        }

        return $selection
    }
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

    Update-PwNexusMetadataCache `
        -ModId @($ModId) `
        -ApiKey $ApiKey `
        -Refresh |
        Out-Null
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

    Update-PwNexusMetadataCache `
        -ModId @($ModId) `
        -ApiKey $ApiKey `
        -Refresh |
        Out-Null
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

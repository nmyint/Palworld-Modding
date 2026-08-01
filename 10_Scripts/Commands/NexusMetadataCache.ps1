<#
.SYNOPSIS
    Provides the persistent catalog-wide Nexus metadata cache.
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
    $schemaVersion = if ($cache.PSObject.Properties['SchemaVersion']) {
        [string]$cache.SchemaVersion
    }
    else {
        ''
    }
    $gameDomain = if ($cache.PSObject.Properties['GameDomain']) {
        [string]$cache.GameDomain
    }
    else {
        ''
    }

    if ($schemaVersion -ne $script:PwNexusMetadataCacheSchemaVersion) {
        throw "Unsupported Nexus metadata cache schema: '$schemaVersion'."
    }

    if ($gameDomain -ne $script:PwNexusGameDomain) {
        throw "Unexpected Nexus metadata cache game domain: '$gameDomain'."
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

    $cache.CatalogModIds = @($cache.CatalogModIds)
    $cache.Mods = @($cache.Mods)
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
    $temporaryPath = Join-Path `
        $parent `
        ('.NexusMetadata-{0}.tmp' -f [guid]::NewGuid().ToString('N'))

    try {
        Write-PwJson `
            -InputObject $Cache `
            -Path $temporaryPath `
            -Depth 100 `
            -Confirm:$false
        Move-Item `
            -LiteralPath $temporaryPath `
            -Destination $Path `
            -Force `
            -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item `
                -LiteralPath $temporaryPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
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
    $existingEntries = @($cache.Mods)
    $existingById = @{}

    foreach ($entry in $existingEntries) {
        if (
            $null -ne $entry -and
            $entry.PSObject.Properties['NexusModId'] -and
            [string]$entry.NexusModId -match '^\d+$'
        ) {
            $existingById[[int]$entry.NexusModId] = $entry
        }
    }

    $cacheWasEmpty = $existingEntries.Count -eq 0
    $fullRefresh = $cacheWasEmpty -or ($Refresh -and $requestedIds.Count -eq 0)
    $targetIds = if ($cacheWasEmpty) {
        @($coverageIds)
    }
    elseif ($Refresh -and $requestedIds.Count -gt 0) {
        @($requestedIds)
    }
    elseif ($Refresh) {
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
    $nowText = (Get-Date).ToUniversalTime().ToString('o')
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
    $entryCountChanged = $existingEntries.Count -ne $retained.Count

    if ($catalogChanged -or $entryCountChanged) {
        $changed = $true
    }

    if (-not $changed) {
        return $cache
    }

    if ($null -eq $cache.CreatedAt) {
        $cache.CreatedAt = $nowText
    }

    $cache.UpdatedAt = $nowText
    $cache.CatalogModIds = @($catalogIds)
    $cache.Mods = @($retained | Sort-Object NexusModId)

    if ($fullRefresh) {
        $cache.LastFullRefreshAt = $nowText
    }

    Write-PwNexusMetadataCache -Cache $cache -Path $Path
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
    $refreshErrors = @(
        $entries |
            Where-Object {
                $_.PSObject.Properties['LastRefreshError'] -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$_.LastRefreshError
                )
            }
    )
    $catalogIds = @(Get-PwCatalogNexusModIds)
    $cachedIds = @(
        $entries |
            Where-Object {
                $null -ne $_ -and
                $_.PSObject.Properties['NexusModId'] -and
                [string]$_.NexusModId -match '^\d+$'
            } |
            ForEach-Object { [int]$_.NexusModId } |
            Sort-Object -Unique
    )
    $hasCoverage = (
        $catalogIds.Count -eq $cachedIds.Count -and
        ($catalogIds -join ',') -eq ($cachedIds -join ',')
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
        RefreshErrorCount = $refreshErrors.Count
        IsComplete = ($hasCoverage -and $errors.Count -eq 0)
        IsCurrent = (
            $hasCoverage -and
            $errors.Count -eq 0 -and
            $refreshErrors.Count -eq 0
        )
    }
}

function Find-PwNexusCachedFile {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
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
        Remove-Item `
            -LiteralPath (Get-PwNexusMetadataCachePath) `
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
    $refreshErrorCount = if (
        $info.PSObject.Properties['RefreshErrorCount']
    ) {
        [int]$info.RefreshErrorCount
    }
    else {
        0
    }
    $suffix = (
        "Nexus cache: $timestamp | $($info.ReadyModCount)/" +
            "$($info.CatalogModCount) mods"
    )

    if ($refreshErrorCount -gt 0) {
        $suffix += " | $refreshErrorCount refresh error"

        if ($refreshErrorCount -ne 1) {
            $suffix += 's'
        }
    }

    $suffix
}

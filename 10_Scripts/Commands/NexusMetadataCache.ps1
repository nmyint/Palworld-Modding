<#
.SYNOPSIS
    Finalizes the persistent catalog-wide Nexus metadata cache behavior.
#>

Set-StrictMode -Version Latest

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

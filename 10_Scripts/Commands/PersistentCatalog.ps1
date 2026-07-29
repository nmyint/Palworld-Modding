<#
.SYNOPSIS
    Persists portable mod metadata and archive version history.
.DESCRIPTION
    Builds a preview from the read-only catalog and merges it with the tracked
    03_Mod_Library\catalog.json manifest. Missing archives remain in history and
    are marked unavailable instead of being deleted.
#>

Set-StrictMode -Version Latest

function Get-PwCatalogManifestPath {

    [CmdletBinding()]
    param()

    Join-Path (Get-PwPaths).ModLibrary 'catalog.json'
}

function New-PwEmptyPersistentCatalog {

    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        SchemaVersion = '1.0'
        UpdatedAt = $null
        Mods = @()
    }
}

<#
.SYNOPSIS
    Reads the tracked persistent catalog, or returns an empty catalog.
#>
function Get-PwPersistentModCatalog {

    [CmdletBinding()]
    param(
        [string]$Path = (Get-PwCatalogManifestPath)
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return New-PwEmptyPersistentCatalog
    }

    $catalog = Read-PwJson -Path $Path

    if ([string]$catalog.SchemaVersion -ne '1.0') {
        throw "Unsupported mod catalog schema: $($catalog.SchemaVersion)"
    }

    $catalog
}

function ConvertTo-PwPortableArchiveVersion {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Archive,

        [bool]$ArchivePresent = $true
    )

    [PSCustomObject]@{
        Version = [string]$Archive.ArchiveVersion
        ArchiveFileName = [string]$Archive.OriginalFileName
        ArchiveFormat = [string]$Archive.ArchiveFormat
        ArchiveLength = [long]$Archive.ArchiveLength
        ArchiveHash = [string]$Archive.ArchiveHash
        ArchivePresent = $ArchivePresent
        DownloadedAt = $Archive.DownloadedAt
        TimestampSource = [string]$Archive.TimestampSource
        FilenamePattern = [string]$Archive.FilenamePattern
    }
}

function Merge-PwCatalogVersions {

    [CmdletBinding()]
    param(
        [object[]]$Existing = @(),

        [object[]]$Discovered = @()
    )

    $versions = [ordered]@{}

    foreach ($version in @($Existing)) {
        if (
            $null -eq $version -or
            $version.PSObject.Properties.Name -notcontains 'ArchiveFileName'
        ) {
            continue
        }

        $archiveHash = if (
            $version.PSObject.Properties.Name -contains 'ArchiveHash'
        ) {
            [string]$version.ArchiveHash
        }
        else {
            ''
        }
        $key = if (-not [string]::IsNullOrWhiteSpace($archiveHash)) {
            $archiveHash
        }
        else {
            [string]$version.ArchiveFileName
        }
        $copy = [ordered]@{}

        foreach ($property in $version.PSObject.Properties) {
            $copy[$property.Name] = $property.Value
        }

        $copy.ArchivePresent = $false
        $versions[$key] = [PSCustomObject]$copy
    }

    foreach ($version in @($Discovered)) {
        if ($null -eq $version) {
            continue
        }

        $key = if (-not [string]::IsNullOrWhiteSpace($version.ArchiveHash)) {
            [string]$version.ArchiveHash
        }
        else {
            [string]$version.ArchiveFileName
        }
        $versions[$key] = $version
    }

    @(
        $versions.Values |
            Sort-Object DownloadedAt, Version
    )
}

<#
.SYNOPSIS
    Previews the persistent-catalog changes without writing files.
.OUTPUTS
    A plan containing the proposed catalog and change counts.
#>
function Get-PwModCatalogSyncPlan {

    [CmdletBinding()]
    param(
        [switch]$SkipContentInspection,

        [string]$Path = (Get-PwCatalogManifestPath)
    )

    $discovery = Get-PwModCatalog `
        -SkipContentInspection:$SkipContentInspection
    $existing = Get-PwPersistentModCatalog -Path $Path
    $existingByKey = @{}

    foreach ($record in @($existing.Mods)) {
        $existingByKey[[string]$record.CatalogKey] = $record
    }

    $records = [System.Collections.Generic.List[object]]::new()
    $seenKeys = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($mod in @($discovery.Mods)) {
        $key = ConvertTo-PwCatalogKey -Value $mod.InstallName
        $seenKeys.Add($key) | Out-Null
        $prior = $existingByKey[$key]
        $archives = @(
            $mod.Archives |
                ForEach-Object {
                    ConvertTo-PwPortableArchiveVersion -Archive $_
                }
        )
        $priorVersions = if ($null -ne $prior) {
            @($prior.Versions)
        }
        else {
            @()
        }
        $nexusIds = @(
            @($mod.NexusModIds) + @(
                if ($null -ne $prior) {
                    @($prior.NexusModIds)
                }
            ) |
                Where-Object { $null -ne $_ -and "$_" -ne '' } |
                Select-Object -Unique
        )

        $records.Add([PSCustomObject]@{
            CatalogKey = $key
            DisplayName = if (
                $null -ne $prior -and
                -not [string]::IsNullOrWhiteSpace($prior.DisplayName)
            ) {
                [string]$prior.DisplayName
            }
            else {
                [string]$mod.Name
            }
            InstallNames = @(
                @($mod.InstallName) + @(
                    if ($null -ne $prior) {
                        @($prior.InstallNames)
                    }
                ) |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )
            Source = 'NexusMods'
            NexusModIds = $nexusIds
            InstalledVersion = if ($null -ne $prior) {
                [string]$prior.InstalledVersion
            }
            else {
                ''
            }
            InstalledContentHash = [string]$mod.InstalledContentHash
            Enabled = $mod.Enabled
            Types = @($mod.Types)
            ReconciliationStatus = if (
                $mod.ArchiveMatchStatus -eq 'MissingArchive'
            ) {
                'NeedsMetadata'
            }
            else {
                'Matched'
            }
            Versions = @(
                Merge-PwCatalogVersions `
                    -Existing $priorVersions `
                    -Discovered $archives
            )
        })
    }

    foreach ($archive in @($discovery.ArchiveOnly)) {
        $key = [string]$archive.CatalogKey

        if (-not $seenKeys.Add($key)) {
            continue
        }

        $prior = $existingByKey[$key]
        $records.Add([PSCustomObject]@{
            CatalogKey = $key
            DisplayName = [string]$archive.Name
            InstallNames = @($archive.InstallNames)
            Source = [string]$archive.Source
            NexusModIds = @($archive.NexusModId)
            InstalledVersion = ''
            InstalledContentHash = ''
            Enabled = $null
            Types = @($archive.Categories)
            ReconciliationStatus = 'ArchiveOnly'
            Versions = @(
                Merge-PwCatalogVersions `
                    -Existing $(if ($null -ne $prior) {
                        @($prior.Versions)
                    } else {
                        @()
                    }) `
                    -Discovered @(
                        ConvertTo-PwPortableArchiveVersion -Archive $archive
                    )
            )
        })
    }

    foreach ($prior in @($existing.Mods)) {
        if ($seenKeys.Contains([string]$prior.CatalogKey)) {
            continue
        }

        $copy = [ordered]@{}

        foreach ($property in $prior.PSObject.Properties) {
            $copy[$property.Name] = $property.Value
        }

        $copy.ReconciliationStatus = 'NotCurrentlyDiscovered'
        $copy.Versions = @(
            Merge-PwCatalogVersions -Existing @($prior.Versions)
        )
        $records.Add([PSCustomObject]$copy)
    }

    $proposed = [PSCustomObject]@{
        SchemaVersion = '1.0'
        UpdatedAt = (Get-Date).ToUniversalTime().ToString('o')
        Mods = @($records | Sort-Object DisplayName)
    }
    $beforeJson = $existing | ConvertTo-Json -Depth 20 -Compress
    $afterComparable = [PSCustomObject]@{
        SchemaVersion = $proposed.SchemaVersion
        UpdatedAt = $existing.UpdatedAt
        Mods = $proposed.Mods
    }
    $afterJson = $afterComparable | ConvertTo-Json -Depth 20 -Compress

    [PSCustomObject]@{
        Path = [System.IO.Path]::GetFullPath($Path)
        HasChanges = $beforeJson -ne $afterJson
        ExistingModCount = @($existing.Mods).Count
        ProposedModCount = @($proposed.Mods).Count
        NeedsMetadataCount = @(
            $proposed.Mods |
                Where-Object ReconciliationStatus -eq 'NeedsMetadata'
        ).Count
        Catalog = $proposed
        DiscoveryWarnings = @($discovery.Warnings)
    }
}

<#
.SYNOPSIS
    Applies a previously previewable persistent-catalog synchronization.
#>
function Update-PwModCatalog {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [switch]$SkipContentInspection,

        [string]$Path = (Get-PwCatalogManifestPath)
    )

    $plan = Get-PwModCatalogSyncPlan `
        -SkipContentInspection:$SkipContentInspection `
        -Path $Path

    if (-not $plan.HasChanges) {
        return $plan
    }

    if ($PSCmdlet.ShouldProcess($plan.Path, 'Update persistent mod catalog')) {
        $parent = Split-Path -Parent $plan.Path
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Write-PwJson -InputObject $plan.Catalog -Path $plan.Path -Depth 20
    }

    $plan
}

<#
.SYNOPSIS
    Records reviewed identity/version metadata for an ambiguous catalog entry.
.DESCRIPTION
    Updates only the tracked catalog manifest. It does not rename, move, unpack,
    deploy, or modify a mod archive or game file.
#>
function Set-PwModCatalogMetadata {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CatalogKey,

        [string]$DisplayName,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$NexusModId,

        [string]$InstalledVersion,

        [string]$Path = (Get-PwCatalogManifestPath)
    )

    $catalog = Get-PwPersistentModCatalog -Path $Path
    $records = @(
        $catalog.Mods |
            Where-Object CatalogKey -eq $CatalogKey
    )

    if ($records.Count -eq 0) {
        throw "Catalog record was not found: $CatalogKey"
    }

    if ($records.Count -gt 1) {
        throw "Catalog key is not unique: $CatalogKey"
    }

    $record = $records[0]

    if ($PSBoundParameters.ContainsKey('DisplayName')) {
        $record.DisplayName = $DisplayName
    }

    if ($PSBoundParameters.ContainsKey('NexusModId')) {
        $record.NexusModIds = @(
            @($record.NexusModIds) + $NexusModId |
                Select-Object -Unique
        )
        $record.Source = 'NexusMods'
    }

    if ($PSBoundParameters.ContainsKey('InstalledVersion')) {
        $record.InstalledVersion = $InstalledVersion
    }

    if (
        @($record.NexusModIds).Count -gt 0 -or
        -not [string]::IsNullOrWhiteSpace($record.InstalledVersion)
    ) {
        $record.ReconciliationStatus = 'ManuallyReconciled'
    }

    $catalog.UpdatedAt = (Get-Date).ToUniversalTime().ToString('o')

    if ($PSCmdlet.ShouldProcess($Path, "Reconcile '$CatalogKey' metadata")) {
        Write-PwJson -InputObject $catalog -Path $Path -Depth 20
    }

    $record
}

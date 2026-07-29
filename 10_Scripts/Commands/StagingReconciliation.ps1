<#
.SYNOPSIS
    Reconciles legacy UE4SS folders and normalized game-layout staging content.
#>

Set-StrictMode -Version Latest

function Test-PwStagingRuntimeArtifact {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $normalized = $Path.Replace('\', '/')
    $leaf = [System.IO.Path]::GetFileName($normalized)

    (
        $leaf -match '(?i)\.log$' -or
        $normalized -match '(?i)(^|/)logs(/|$)' -or
        $leaf -in @(
            'logs-index.txt',
            'defeated.tsv',
            'mods.json',
            'mods.txt',
            'test.ps1'
        )
    )
}

function Get-PwStagingComponentOwnerName {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [ValidateSet('UE4SSLua', 'Native', 'Pak', 'LogicMods', 'Configuration')]
        [string]$PackageType
    )

    $normalized = $RelativePath.Replace('\', '/')
    $segments = @(
        $normalized.Split(
            '/',
            [System.StringSplitOptions]::RemoveEmptyEntries
        )
    )

    if ($PackageType -in @('UE4SSLua', 'Native')) {
        return $segments[0]
    }

    if ($segments.Count -gt 1) {
        return $segments[0]
    }

    $name = [System.IO.Path]::GetFileNameWithoutExtension($segments[0])
    $name = $name -replace '(?i)\.modconfig$', ''
    $name = $name -replace '(?i)_P$', ''
    $name
}

function Find-PwStagingCatalogOwner {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OwnerName,

        [Parameter(Mandatory)]
        [object[]]$CatalogMods
    )

    $ownerKey = ConvertTo-PwCatalogKey -Value $OwnerName
    $explicit = @(
        $CatalogMods |
            Where-Object {
                $_.PSObject.Properties['ComponentNames'] -and
                $ownerKey -in @(
                    @($_.ComponentNames) |
                        Where-Object {
                            -not [string]::IsNullOrWhiteSpace([string]$_)
                        } |
                        ForEach-Object {
                            ConvertTo-PwCatalogKey -Value ([string]$_)
                        }
                )
            }
    )

    if ($explicit.Count -eq 1) {
        return [PSCustomObject]@{
            Status = 'Matched'
            CatalogKey = [string]$explicit[0].CatalogKey
            DisplayName = [string]$explicit[0].DisplayName
            Confidence = 'ExplicitComponent'
        }
    }

    if ($explicit.Count -gt 1) {
        return [PSCustomObject]@{
            Status = 'Ambiguous'
            CatalogKey = ''
            DisplayName = ''
            Confidence = 'None'
        }
    }

    $exact = @(
        $CatalogMods |
            Where-Object {
                $keys = @(
                    [string]$_.CatalogKey
                    [string]$_.DisplayName
                    @($_.InstallNames)
                ) |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace([string]$_)
                    } |
                    ForEach-Object {
                        ConvertTo-PwCatalogKey -Value ([string]$_)
                    }

                $ownerKey -in $keys
            }
    )

    if ($exact.Count -eq 1) {
        return [PSCustomObject]@{
            Status = 'Matched'
            CatalogKey = [string]$exact[0].CatalogKey
            DisplayName = [string]$exact[0].DisplayName
            Confidence = 'Exact'
        }
    }

    if ($exact.Count -gt 1) {
        return [PSCustomObject]@{
            Status = 'Ambiguous'
            CatalogKey = ''
            DisplayName = ''
            Confidence = 'None'
        }
    }

    $prefix = @(
        $CatalogMods |
            Where-Object {
                $candidateKey = ConvertTo-PwCatalogKey -Value (
                    [string]$_.CatalogKey
                )
                (
                    $candidateKey.StartsWith($ownerKey) -or
                    $ownerKey.StartsWith($candidateKey)
                )
            }
    )

    if ($prefix.Count -eq 1) {
        return [PSCustomObject]@{
            Status = 'Matched'
            CatalogKey = [string]$prefix[0].CatalogKey
            DisplayName = [string]$prefix[0].DisplayName
            Confidence = 'UniquePrefix'
        }
    }

    [PSCustomObject]@{
        Status = 'Unmatched'
        CatalogKey = ''
        DisplayName = $OwnerName
        Confidence = 'None'
    }
}

function New-PwStagingComponent {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StagingRoot,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$SourceArea,

        [Parameter(Mandatory)]
        [ValidateSet('UE4SSLua', 'Native', 'Pak', 'LogicMods', 'Configuration')]
        [string]$PackageType,

        [Parameter(Mandatory)]
        [object[]]$CatalogMods
    )

    $relativePath = [System.IO.Path]::GetRelativePath(
        $StagingRoot,
        $Path
    ).Replace('\', '/')
    $areaRoot = switch ($SourceArea) {
        'UE4SS' {
            Get-PwStagingModsRoot -StagingRoot $StagingRoot
        }
        '~mods' {
            Join-Path $StagingRoot 'Pal\Content\Paks\~mods'
        }
        'LogicMods' {
            Join-Path $StagingRoot 'Pal\Content\Paks\LogicMods'
        }
    }
    $ownerRelativePath = [System.IO.Path]::GetRelativePath(
        $areaRoot,
        $Path
    ).Replace('\', '/')
    $ownerName = Get-PwStagingComponentOwnerName `
        -RelativePath $ownerRelativePath `
        -PackageType $PackageType
    $owner = Find-PwStagingCatalogOwner `
        -OwnerName $ownerName `
        -CatalogMods $CatalogMods

    [PSCustomObject]@{
        OwnerName = $ownerName
        CatalogKey = $owner.CatalogKey
        DisplayName = $owner.DisplayName
        OwnershipStatus = $owner.Status
        Confidence = $owner.Confidence
        SourceArea = $SourceArea
        PackageType = $PackageType
        RelativePath = $relativePath
        Length = (Get-Item -LiteralPath $Path).Length
        Hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

<#
.SYNOPSIS
    Produces a read-only component ownership report for 02_Staging.
.DESCRIPTION
    Supports the existing top-level UE4SS folders and normalized game-relative
    PAK roots. Files are grouped only when their owner name exactly matches a
    reviewed catalog identity; ambiguous files remain explicit review items.
#>
function Get-PwStagingReconciliation {

    [CmdletBinding()]
    param(
        [string]$Path = (Get-PwPaths).Staging
    )

    $stagingRoot = [System.IO.Path]::GetFullPath($Path)

    if (-not (Test-Path -LiteralPath $stagingRoot -PathType Container)) {
        throw "Staging root does not exist: $stagingRoot"
    }

    $catalog = Get-PwPersistentModCatalog
    $catalogMods = @($catalog.Mods)
    $components = [System.Collections.Generic.List[object]]::new()
    $excludedItems = [System.Collections.Generic.List[object]]::new()

    $ue4ssRoot = Get-PwStagingModsRoot -StagingRoot $stagingRoot

    foreach (
        $directory in Get-ChildItem -LiteralPath $ue4ssRoot -Directory |
            Where-Object Name -notin @('Pal', '~mods', 'LogicMods') |
            Sort-Object Name
    ) {
        if (Test-Path -LiteralPath (
            Join-Path $directory.FullName 'manifest.json'
        )) {
            continue
        }

        foreach (
            $file in Get-ChildItem -LiteralPath $directory.FullName -Recurse -File
        ) {
            if (Test-PwStagingRuntimeArtifact -Path $file.FullName) {
                $excludedItems.Add([PSCustomObject]@{
                    RelativePath = [System.IO.Path]::GetRelativePath(
                        $stagingRoot,
                        $file.FullName
                    ).Replace('\', '/')
                    Reason = 'RuntimeState'
                })
                continue
            }
            $packageType = switch ($file.Extension.ToLowerInvariant()) {
                '.lua' { 'UE4SSLua' }
                '.dll' { 'Native' }
                default { 'Configuration' }
            }
            $components.Add(
                (New-PwStagingComponent `
                    -StagingRoot $stagingRoot `
                    -Path $file.FullName `
                    -SourceArea UE4SS `
                    -PackageType $packageType `
                    -CatalogMods $catalogMods)
            )
        }
    }

    foreach ($area in @('~mods', 'LogicMods')) {
        $areaRoot = Join-Path $stagingRoot "Pal\Content\Paks\$area"

        if (-not (Test-Path -LiteralPath $areaRoot -PathType Container)) {
            continue
        }

        foreach ($file in Get-ChildItem -LiteralPath $areaRoot -Recurse -File) {
            if (Test-PwStagingRuntimeArtifact -Path $file.FullName) {
                $excludedItems.Add([PSCustomObject]@{
                    RelativePath = [System.IO.Path]::GetRelativePath(
                        $stagingRoot,
                        $file.FullName
                    ).Replace('\', '/')
                    Reason = 'RuntimeState'
                })
                continue
            }
            $packageType = if (
                $file.Extension -in @('.pak', '.utoc', '.ucas')
            ) {
                if ($area -eq 'LogicMods') {
                    'LogicMods'
                }
                else {
                    'Pak'
                }
            }
            else {
                'Configuration'
            }
            $components.Add(
                (New-PwStagingComponent `
                    -StagingRoot $stagingRoot `
                    -Path $file.FullName `
                    -SourceArea $area `
                    -PackageType $packageType `
                    -CatalogMods $catalogMods)
            )
        }
    }

    $groups = @(
        $components |
            Where-Object OwnershipStatus -eq 'Matched' |
            Group-Object CatalogKey |
            ForEach-Object {
                $packageTypes = @(
                    $_.Group.PackageType |
                        Where-Object { $_ -ne 'Configuration' } |
                        Select-Object -Unique |
                        Sort-Object
                )

                [PSCustomObject]@{
                    CatalogKey = $_.Name
                    DisplayName = $_.Group[0].DisplayName
                    PackageTypes = $packageTypes
                    IsMixedPackage = $packageTypes.Count -gt 1
                    ComponentCount = $_.Count
                    Components = @($_.Group)
                }
            } |
            Sort-Object DisplayName
    )
    $reviewItems = @(
        $components |
            Where-Object OwnershipStatus -ne 'Matched' |
            Sort-Object OwnerName, RelativePath
    )

    [PSCustomObject]@{
        StagingRoot = $stagingRoot
        ComponentCount = $components.Count
        MatchedComponentCount = @(
            $components |
                Where-Object OwnershipStatus -eq 'Matched'
        ).Count
        MixedPackageCount = @(
            $groups |
                Where-Object IsMixedPackage
        ).Count
        ReviewItemCount = $reviewItems.Count
        ExcludedItemCount = $excludedItems.Count
        ExcludedItems = @($excludedItems)
        Groups = $groups
        ReviewItems = $reviewItems
        Components = @($components)
    }
}

function Get-PwCompatibilityReport {

    [CmdletBinding()]
    param(
        [string]$Path = (Get-PwPaths).Staging
    )

    $staging = Get-PwStagingReconciliation -Path $Path
    $catalog = Get-PwPersistentModCatalog
    $mods = @($catalog.Mods)

    $archiveEntries = @(
        foreach ($mod in $mods) {
            foreach ($version in @($mod.Versions)) {
                if ([string]::IsNullOrWhiteSpace([string]$version.ArchiveHash)) {
                    continue
                }

                [PSCustomObject]@{
                    ArchiveHash = [string]$version.ArchiveHash
                    CatalogKey = [string]$mod.CatalogKey
                    DisplayName = [string]$mod.DisplayName
                    Version = [string]$version.Version
                }
            }
        }
    )
    $duplicateArchives = @(
        $archiveEntries |
            Group-Object ArchiveHash |
            Where-Object Count -gt 1 |
            ForEach-Object {
                $catalogKeys = @(
                    $_.Group.CatalogKey |
                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                        Sort-Object -Unique
                )
                $isReviewedBundle = $false

                foreach ($catalogKey in $catalogKeys) {
                    $owner = $mods |
                        Where-Object CatalogKey -eq $catalogKey |
                        Select-Object -First 1
                    $componentKeys = @(
                        if (
                            $null -ne $owner -and
                            $owner.PSObject.Properties['ComponentNames']
                        ) {
                            @($owner.ComponentNames) |
                                ForEach-Object {
                                    ConvertTo-PwCatalogKey -Value ([string]$_)
                                }
                        }
                    )
                    if (
                        @(
                            $catalogKeys |
                                Where-Object {
                                    $_ -ne $catalogKey -and
                                    $_ -in $componentKeys
                                }
                        ).Count -gt 0
                    ) {
                        $isReviewedBundle = $true
                        break
                    }
                }

                if (-not $isReviewedBundle) {
                    [PSCustomObject]@{
                        ArchiveHash = $_.Name
                        CatalogKeys = $catalogKeys
                        Versions = @(
                            $_.Group.Version |
                                Where-Object {
                                    -not [string]::IsNullOrWhiteSpace($_)
                                } |
                                Sort-Object -Unique
                        )
                    }
                }
            }
    )

    $mixedPackages = @(
        $staging.Groups |
            Where-Object IsMixedPackage
    )
    $variantWarnings = @(
        $mods |
            ForEach-Object {
                $platforms = @(
                    @($_.Versions) |
                        ForEach-Object { [string]$_.Platform } |
                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                        Select-Object -Unique
                )
                $playModes = @(
                    @($_.Versions) |
                        ForEach-Object { [string]$_.PlayMode } |
                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                        Select-Object -Unique
                )

                if ($platforms.Count -gt 1 -or $playModes.Count -gt 1) {
                    [PSCustomObject]@{
                        CatalogKey = [string]$_.CatalogKey
                        DisplayName = [string]$_.DisplayName
                        Platforms = $platforms
                        PlayModes = $playModes
                    }
                }
            } |
            Where-Object { $null -ne $_ }
    )

    [PSCustomObject]@{
        GeneratedAt = (Get-Date).ToUniversalTime()
        Staging = $staging
        DuplicateArchives = $duplicateArchives
        MixedPackages = $mixedPackages
        VariantWarnings = $variantWarnings
        # Mixed deployment formats are valid when they share reviewed ownership.
        # Path-level conflicts will be added by deterministic assembly.
        ConflictCount = 0
        ReviewCount = (
            $staging.ReviewItemCount +
            $variantWarnings.Count +
            $duplicateArchives.Count
        )
    }
}

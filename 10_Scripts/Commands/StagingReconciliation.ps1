<#
.SYNOPSIS
    Reconciles legacy UE4SS folders and normalized game-layout staging content.
#>

Set-StrictMode -Version Latest

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
            $StagingRoot
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

    foreach (
        $directory in Get-ChildItem -LiteralPath $stagingRoot -Directory |
            Where-Object Name -ne 'Pal' |
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
        Groups = $groups
        ReviewItems = $reviewItems
        Components = @($components)
    }
}

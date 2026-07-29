<#
.SYNOPSIS
    Builds preview-only plans for curated mod upgrades and removals.
.DESCRIPTION
    Compares manifest-backed packages by deployment-relative path and SHA-256.
    These commands never copy, overwrite, or remove files. They provide the
    ownership and rollback information required by the later apply workflow.
#>

Set-StrictMode -Version Latest

function Get-PwLibraryPackageManifest {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CatalogKey,

        [string]$Version = ''
    )

    $libraryRoot = (Get-PwPaths).ModLibrary
    $matches = @(
        Get-ChildItem -LiteralPath $libraryRoot -Directory |
            ForEach-Object {
                $manifestPath = Join-Path $_.FullName 'manifest.json'
                if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
                    return
                }

                try {
                    $manifest = Read-PwJson -Path $manifestPath
                }
                catch {
                    return
                }

                if ([string]$manifest.Name -ine $CatalogKey) {
                    return
                }
                if (
                    -not [string]::IsNullOrWhiteSpace($Version) -and
                    [string]$manifest.Version -ine $Version
                ) {
                    return
                }

                [PSCustomObject]@{
                    CatalogKey = [string]$manifest.Name
                    Version = [string]$manifest.Version
                    LibraryRoot = $_.FullName
                    ManifestPath = $manifestPath
                    Manifest = $manifest
                }
            }
    )

    if ($matches.Count -eq 0) {
        throw "No curated package was found for '$CatalogKey' version '$Version'."
    }
    if ($matches.Count -gt 1) {
        throw (
            "More than one curated package matched '$CatalogKey'. " +
            'Specify -Version to select one package.'
        )
    }

    $matches[0]
}

function ConvertTo-PwDeploymentPackagePath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath
    )

    $value = $RelativePath.Replace('/', '\')
    if ($value -match '^(?i:Pal)\\(.+)$') {
        return $Matches[1]
    }

    $value
}

function Get-PwProfilePackageOwnership {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [string]$ExcludeCatalogKey = ''
    )

    $ownership = @{}
    $preview = Get-PwProfileModSetPreview -Name $ProfileName

    foreach ($mod in @($preview.Mods)) {
        if ([string]$mod.CatalogKey -ieq $ExcludeCatalogKey) {
            continue
        }

        try {
            $package = Get-PwLibraryPackageManifest `
                -CatalogKey ([string]$mod.CatalogKey) `
                -Version ([string]$mod.InstalledVersion)
        }
        catch {
            continue
        }

        foreach ($entry in @($package.Manifest.Entries)) {
            $relativePath = ConvertTo-PwDeploymentPackagePath `
                -RelativePath ([string]$entry.DeploymentRelativePath)
            $key = $relativePath.ToLowerInvariant()
            if (-not $ownership.ContainsKey($key)) {
                $ownership[$key] = [System.Collections.Generic.List[string]]::new()
            }
            $ownership[$key].Add([string]$mod.CatalogKey)
        }
    }

    $ownership
}

function Get-PwModRemovalPlan {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CatalogKey,

        [string]$ProfileName = (
            (Get-PwWorkshopConfig).Deployment.ActiveProfile
        ),

        [string]$Version = ''
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        $record = (Get-PwPersistentModCatalog).Mods |
            Where-Object CatalogKey -eq $CatalogKey |
            Select-Object -First 1
        if ($record) {
            $Version = [string]$record.InstalledVersion
        }
    }

    $package = Get-PwLibraryPackageManifest `
        -CatalogKey $CatalogKey `
        -Version $Version
    $deploymentRoot = (Get-PwDeployment).TargetRoot
    $otherOwners = Get-PwProfilePackageOwnership `
        -ProfileName $ProfileName `
        -ExcludeCatalogKey $CatalogKey
    $files = @(
        foreach ($entry in @($package.Manifest.Entries)) {
            $relativePath = ConvertTo-PwDeploymentPackagePath `
                -RelativePath ([string]$entry.DeploymentRelativePath)
            $targetPath = Join-Path $deploymentRoot $relativePath
            $owners = @($otherOwners[$relativePath.ToLowerInvariant()])
            $state = 'Missing'
            $actualHash = ''

            if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
                $actualHash = (Get-FileHash -LiteralPath $targetPath).Hash
                $state = if ($actualHash -eq [string]$entry.Hash) {
                    'Owned'
                }
                else {
                    'Modified'
                }
            }
            if ($owners.Count -gt 0) {
                $state = 'Shared'
            }

            [PSCustomObject]@{
                RelativePath = $relativePath
                State = $state
                ExpectedHash = [string]$entry.Hash
                ActualHash = $actualHash
                OtherOwners = $owners
                RequiresBackup = $state -in @('Owned', 'Modified')
                PlannedAction = if ($state -eq 'Owned') { 'Remove' } else { 'Keep' }
            }
        }
    )
    $modified = @($files | Where-Object State -eq 'Modified')

    [PSCustomObject]@{
        SchemaVersion = '1.0'
        PlanType = 'Removal'
        PreviewOnly = $true
        Profile = $ProfileName
        CatalogKey = $CatalogKey
        Version = [string]$package.Version
        ManifestPath = $package.ManifestPath
        DeploymentRoot = $deploymentRoot
        FileCount = $files.Count
        RemoveCount = @($files | Where-Object PlannedAction -eq 'Remove').Count
        SharedCount = @($files | Where-Object State -eq 'Shared').Count
        ModifiedCount = $modified.Count
        MissingCount = @($files | Where-Object State -eq 'Missing').Count
        BackupRequired = @($files | Where-Object RequiresBackup).Count -gt 0
        CanApply = $modified.Count -eq 0
        Files = $files
    }
}

function Get-PwModUpgradePlan {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CatalogKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CandidateVersion,

        [string]$ProfileName = (
            (Get-PwWorkshopConfig).Deployment.ActiveProfile
        ),

        [string]$CurrentVersion = ''
    )

    if ([string]::IsNullOrWhiteSpace($CurrentVersion)) {
        $record = (Get-PwPersistentModCatalog).Mods |
            Where-Object CatalogKey -eq $CatalogKey |
            Select-Object -First 1
        if ($record) {
            $CurrentVersion = [string]$record.InstalledVersion
        }
    }

    $current = Get-PwLibraryPackageManifest `
        -CatalogKey $CatalogKey `
        -Version $CurrentVersion
    $candidate = Get-PwLibraryPackageManifest `
        -CatalogKey $CatalogKey `
        -Version $CandidateVersion
    $currentByPath = @{}
    $candidateByPath = @{}

    foreach ($entry in @($current.Manifest.Entries)) {
        $path = ConvertTo-PwDeploymentPackagePath `
            -RelativePath ([string]$entry.DeploymentRelativePath)
        $currentByPath[$path.ToLowerInvariant()] = $entry
    }
    foreach ($entry in @($candidate.Manifest.Entries)) {
        $path = ConvertTo-PwDeploymentPackagePath `
            -RelativePath ([string]$entry.DeploymentRelativePath)
        $candidateByPath[$path.ToLowerInvariant()] = $entry
    }

    $allPaths = @(
        @($currentByPath.Keys) + @($candidateByPath.Keys) |
            Sort-Object -Unique
    )
    $files = @(
        foreach ($key in $allPaths) {
            $oldEntry = $currentByPath[$key]
            $newEntry = $candidateByPath[$key]
            $action = if ($null -eq $oldEntry) {
                'Create'
            }
            elseif ($null -eq $newEntry) {
                'Remove'
            }
            elseif ([string]$oldEntry.Hash -eq [string]$newEntry.Hash) {
                'Unchanged'
            }
            else {
                'Update'
            }
            $sourceEntry = if ($null -ne $newEntry) { $newEntry } else { $oldEntry }

            [PSCustomObject]@{
                RelativePath = ConvertTo-PwDeploymentPackagePath `
                    -RelativePath ([string]$sourceEntry.DeploymentRelativePath)
                PlannedAction = $action
                CurrentHash = if ($oldEntry) { [string]$oldEntry.Hash } else { '' }
                CandidateHash = if ($newEntry) { [string]$newEntry.Hash } else { '' }
                RequiresBackup = $action -in @('Update', 'Remove')
            }
        }
    )

    [PSCustomObject]@{
        SchemaVersion = '1.0'
        PlanType = 'Upgrade'
        PreviewOnly = $true
        Profile = $ProfileName
        CatalogKey = $CatalogKey
        CurrentVersion = [string]$current.Version
        CandidateVersion = [string]$candidate.Version
        CurrentManifestPath = $current.ManifestPath
        CandidateManifestPath = $candidate.ManifestPath
        FileCount = $files.Count
        CreateCount = @($files | Where-Object PlannedAction -eq 'Create').Count
        UpdateCount = @($files | Where-Object PlannedAction -eq 'Update').Count
        RemoveCount = @($files | Where-Object PlannedAction -eq 'Remove').Count
        UnchangedCount = @($files | Where-Object PlannedAction -eq 'Unchanged').Count
        BackupRequired = @($files | Where-Object RequiresBackup).Count -gt 0
        CanApply = $true
        Files = $files
    }
}

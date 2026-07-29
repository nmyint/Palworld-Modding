<#
.SYNOPSIS
    Captures reconciled staging content and assembles profile deployments.
.DESCRIPTION
    Converts the reviewed 02_Staging snapshot into manifest-backed packages in
    03_Mod_Library and deterministic loose output beneath 05_Deployment. This
    command never writes to the live game installation.
#>

Set-StrictMode -Version Latest

function Get-PwContentSetHash {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Entries
    )

    $lines = @(
        $Entries |
            Sort-Object RelativePath |
            ForEach-Object {
                '{0}|{1}|{2}' -f (
                    [string]$_.RelativePath
                ).Replace('\', '/').ToLowerInvariant(),
                [string]$_.Length,
                ([string]$_.Hash).ToUpperInvariant()
            }
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()

    try {
        ([System.BitConverter]::ToString(
            $sha.ComputeHash($bytes)
        )).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Get-PwProfileAssemblyPlan {

    [CmdletBinding()]
    param(
        [string]$ProfileName = (
            (Get-PwWorkshopConfig).Deployment.ActiveProfile
        )
    )

    $preview = Get-PwProfileModSetPreview -Name $ProfileName
    $reconciliation = Get-PwStagingReconciliation
    $catalog = Get-PwPersistentModCatalog
    $selectedKeys = @($preview.Mods.CatalogKey)
    $packages = @(
        foreach (
            $group in $reconciliation.Groups |
                Where-Object CatalogKey -in $selectedKeys |
                Sort-Object CatalogKey
        ) {
            $record = $catalog.Mods |
                Where-Object CatalogKey -eq $group.CatalogKey |
                Select-Object -First 1
            $version = [string]$record.InstalledVersion

            if (
                [string]::IsNullOrWhiteSpace($version) -or
                -not (Test-PwModIdentifier -Value $version)
            ) {
                $version = 'working'
            }

            $libraryRoot = Get-PwModPackageRoot `
                -Area ModLibrary `
                -Name $group.CatalogKey `
                -Version $version
            $contentHash = Get-PwContentSetHash -Entries $group.Components
            $action = 'Create'

            if (Test-Path -LiteralPath $libraryRoot -PathType Container) {
                $manifestPath = Join-Path $libraryRoot 'manifest.json'
                $action = 'Conflict'

                if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
                    try {
                        $existing = Read-PwJson -Path $manifestPath
                        if (
                            $existing.PSObject.Properties['ContentSetHash'] -and
                            [string]$existing.ContentSetHash -eq $contentHash
                        ) {
                            $action = 'Reuse'
                        }
                        elseif (
                            $existing.PSObject.Properties['CaptureSource'] -and
                            [string]$existing.CaptureSource -eq '02_Staging'
                        ) {
                            $action = 'Refresh'
                        }
                    }
                    catch {
                        $action = 'Conflict'
                    }
                }
            }

            [PSCustomObject]@{
                CatalogKey = [string]$group.CatalogKey
                DisplayName = [string]$group.DisplayName
                Version = $version
                LibraryRoot = $libraryRoot
                ContentSetHash = $contentHash
                PackageTypes = @($group.PackageTypes)
                FileCount = @($group.Components).Count
                Action = $action
                Components = @($group.Components)
            }
        }
    )
    $assembledKeys = @($packages.CatalogKey)
    $missingKeys = @(
        $selectedKeys |
            Where-Object { $_ -notin $assembledKeys } |
            Sort-Object -Unique
    )
    $packageConflicts = @(
        $packages |
            Where-Object Action -eq 'Conflict'
    )

    $deploymentEntries = @(
        foreach ($package in $packages) {
            foreach ($component in @($package.Components)) {
                $deploymentRelativePath = (
                    [string]$component.RelativePath
                ).Replace('/', '\')

                if (
                    $deploymentRelativePath -match
                        '^(?i:Pal)\\(.+)$'
                ) {
                    $deploymentRelativePath = $Matches[1]
                }

                [PSCustomObject]@{
                    CatalogKey = [string]$package.CatalogKey
                    DisplayName = [string]$package.DisplayName
                    RelativePath = $deploymentRelativePath
                    NormalizedPath = (
                        $deploymentRelativePath
                    ).ToLowerInvariant()
                    Hash = [string]$component.Hash
                }
            }
        }
    )

    $pathConflicts = @(
        $deploymentEntries |
            Group-Object NormalizedPath |
            Where-Object {
                @(
                    $_.Group.CatalogKey |
                        Sort-Object -Unique
                ).Count -gt 1
            } |
            ForEach-Object {
                [PSCustomObject]@{
                    RelativePath = (
                        $_.Group |
                            Select-Object -First 1
                    ).RelativePath
                    CatalogKeys = @(
                        $_.Group.CatalogKey |
                            Sort-Object -Unique
                    )
                    DisplayNames = @(
                        $_.Group.DisplayName |
                            Sort-Object -Unique
                    )
                    Hashes = @(
                        $_.Group.Hash |
                            Where-Object {
                                -not [string]::IsNullOrWhiteSpace($_)
                            } |
                            Sort-Object -Unique
                    )
                }
            } |
            Sort-Object RelativePath
    )

    $conflictCount = (
        $packageConflicts.Count +
        $pathConflicts.Count
    )

    [PSCustomObject]@{
        SchemaVersion = '1.0'
        Profile = $ProfileName
        ModSet = $preview.ModSet
        StagingRoot = $reconciliation.StagingRoot
        DeploymentRoot = (Get-PwDeployment).TargetRoot
        PackageCount = $packages.Count
        FileCount = @(
            $packages |
                ForEach-Object { @($_.Components) }
        ).Count
        CreateCount = @($packages | Where-Object Action -eq 'Create').Count
        RefreshCount = @($packages | Where-Object Action -eq 'Refresh').Count
        ReuseCount = @($packages | Where-Object Action -eq 'Reuse').Count
        PackageConflictCount = $packageConflicts.Count
        PackageConflicts = $packageConflicts
        PathConflictCount = $pathConflicts.Count
        PathConflicts = $pathConflicts
        ConflictCount = $conflictCount
        ReviewItemCount = $reconciliation.ReviewItemCount
        MissingCatalogKeys = $missingKeys
        CanBuild = (
            $reconciliation.ReviewItemCount -eq 0 -and
            $missingKeys.Count -eq 0 -and
            $conflictCount -eq 0
        )
        Packages = $packages
    }
}

function Build-PwProfileDeployment {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$ProfileName = (
            (Get-PwWorkshopConfig).Deployment.ActiveProfile
        ),

        [switch]$Apply
    )

    $plan = Get-PwProfileAssemblyPlan -ProfileName $ProfileName

    if (-not $Apply) {
        return $plan
    }

    if (-not $plan.CanBuild) {
        throw (
            'Profile assembly is blocked by unresolved ownership, missing ' +
            'catalog selections, conflicting library packages, or deployment ' +
            'path conflicts.'
        )
    }

    if (-not $PSCmdlet.ShouldProcess(
        $plan.DeploymentRoot,
        "Build reviewed profile '$ProfileName' without deploying to the game"
    )) {
        return $plan
    }

    $paths = Get-PwPaths
    $assemblyRoot = Join-Path $paths.Deployment '.assembly'
    $assemblyManifestPath = Join-Path $paths.Deployment 'assembly-manifest.json'
    $temporaryRoot = Join-Path (
        Join-Path $paths.Sandbox 'ProfileAssembly'
    ) ([guid]::NewGuid().ToString('N'))
    $files = [System.Collections.Generic.List[object]]::new()
    $packageResults = [System.Collections.Generic.List[object]]::new()
    $createdLibraryRoots = [System.Collections.Generic.List[string]]::new()
    $createdDeploymentFiles = [System.Collections.Generic.List[string]]::new()
    $buildSucceeded = $false

    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null

    try {
        if (Test-Path -LiteralPath $assemblyManifestPath -PathType Leaf) {
            $previousAssembly = Read-PwJson -Path $assemblyManifestPath

            foreach ($previousFile in @($previousAssembly.Files)) {
                $relativePathValue = (
                    [string]$previousFile.RelativePath
                ).Replace('/', '\')
                if ($relativePathValue -match '^(?i:Pal)\\(.+)$') {
                    $relativePathValue = $Matches[1]
                }
                $previousPath = Join-Path `
                    $plan.DeploymentRoot `
                    $relativePathValue

                if (Test-Path -LiteralPath $previousPath -PathType Leaf) {
                    $previousHash = (
                        Get-FileHash `
                            -LiteralPath $previousPath `
                            -Algorithm SHA256
                    ).Hash
                    if ($previousHash -eq [string]$previousFile.Hash) {
                        Remove-Item -LiteralPath $previousPath -Force
                    }
                }
            }
        }

        foreach ($package in $plan.Packages) {
            $sourceRoot = Join-Path $temporaryRoot (
                "$($package.CatalogKey)\Source"
            )
            New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
            $entries = @(
                foreach ($component in $package.Components) {
                    $sourcePath = Join-Path $plan.StagingRoot (
                        $component.RelativePath.Replace('/', '\')
                    )
                    $packageRelativePath = (
                        [string]$component.RelativePath
                    ).Replace('\', '/')
                    $deploymentRelativePath = $packageRelativePath

                    $temporaryPath = Join-Path $sourceRoot (
                        $packageRelativePath.Replace('/', '\')
                    )
                    $temporaryDirectory = Split-Path -Parent $temporaryPath
                    New-Item `
                        -ItemType Directory `
                        -Path $temporaryDirectory `
                        -Force |
                        Out-Null
                    Copy-Item `
                        -LiteralPath $sourcePath `
                        -Destination $temporaryPath `
                        -Force `
                        -ErrorAction Stop

                    [PSCustomObject]@{
                        ArchivePath = $packageRelativePath
                        StagedRelativePath = $packageRelativePath
                        Length = [long]$component.Length
                        Hash = [string]$component.Hash
                        Category = [string]$component.PackageType
                        DeploymentRelativePath = $deploymentRelativePath
                        ReviewRequired = $false
                    }
                }
            )

            if ($package.Action -in @('Create', 'Refresh')) {
                New-Item `
                    -ItemType Directory `
                    -Path $package.LibraryRoot `
                    -Force |
                    Out-Null
                $packageArchive = Join-Path $package.LibraryRoot 'package.7z'
                $generatedArchive = Join-Path (
                    Split-Path -Parent $sourceRoot
                ) 'package.7z'
                $packageHash = New-Pw7ZipArchive `
                    -SourceRoot $sourceRoot `
                    -DestinationPath $generatedArchive
                $manifest = [PSCustomObject]@{
                    SchemaVersion = '1.1'
                    Name = $package.CatalogKey
                    Version = $package.Version
                    Author = ''
                    SourceUri = ''
                    ImportedAt = Get-Date
                    CaptureSource = '02_Staging'
                    OriginalArchive = ''
                    OriginalFormat = 'StagingSnapshot'
                    ArchiveHash = $package.ContentSetHash
                    ContentSetHash = $package.ContentSetHash
                    HashAuthority = 'LocalSHA256'
                    PackageArchive = 'package.7z'
                    PackageArchiveHash = $packageHash
                    RequiresReview = $false
                    Categories = @($package.PackageTypes)
                    Requirements = @(
                        (
                            Get-PwPackageRequirementMetadata -Entries $entries
                        ).Requirements
                    )
                    ExpectedDestinations = @(
                        (
                            Get-PwPackageRequirementMetadata -Entries $entries
                        ).ExpectedDestinations
                    )
                    Entries = $entries
                }
                Copy-Item `
                    -LiteralPath $generatedArchive `
                    -Destination $packageArchive `
                    -Force `
                    -ErrorAction Stop
                Write-PwJson `
                    -InputObject $manifest `
                    -Path (Join-Path $package.LibraryRoot 'manifest.json')
                if ($package.Action -eq 'Create') {
                    $createdLibraryRoots.Add($package.LibraryRoot)
                }
            }

            $validation = Test-PwModPackage `
                -Name $package.CatalogKey `
                -Version $package.Version `
                -Area ModLibrary

            if (-not $validation.IsValid) {
                throw (
                    "Library package validation failed for " +
                    "$($package.CatalogKey): " +
                    ($validation.Errors -join ' ')
                )
            }

            foreach ($entry in $entries) {
                $temporaryPath = Join-Path $sourceRoot (
                    $entry.StagedRelativePath.Replace('/', '\')
                )
                $deploymentPathValue = (
                    [string]$entry.DeploymentRelativePath
                ).Replace('/', '\')
                if ($deploymentPathValue -match '^(?i:Pal)\\(.+)$') {
                    $deploymentPathValue = $Matches[1]
                }
                $destinationPath = Join-Path `
                    $plan.DeploymentRoot `
                    $deploymentPathValue
                $destinationDirectory = Split-Path -Parent $destinationPath
                New-Item `
                    -ItemType Directory `
                    -Path $destinationDirectory `
                    -Force |
                    Out-Null
                Copy-Item `
                    -LiteralPath $temporaryPath `
                    -Destination $destinationPath `
                    -Force `
                    -ErrorAction Stop
                $createdDeploymentFiles.Add($destinationPath)
                $actualHash = (
                    Get-FileHash `
                        -LiteralPath $destinationPath `
                        -Algorithm SHA256
                ).Hash

                if ($actualHash -ne $entry.Hash) {
                    throw (
                        'Assembly hash verification failed: ' +
                        $entry.DeploymentRelativePath
                    )
                }

                $files.Add([PSCustomObject]@{
                    CatalogKey = $package.CatalogKey
                    RelativePath = $entry.DeploymentRelativePath
                    Length = $entry.Length
                    Hash = $actualHash
                    VerificationStatus = 'Verified'
                })
            }

            $requirementMetadata = Get-PwPackageRequirementMetadata `
                -Entries $entries
            $packageResults.Add([PSCustomObject]@{
                CatalogKey = $package.CatalogKey
                Version = $package.Version
                LibraryRoot = $package.LibraryRoot
                ContentSetHash = $package.ContentSetHash
                Action = $package.Action
                ValidationStatus = 'Verified'
                FileCount = $entries.Count
                Requirements = @($requirementMetadata.Requirements)
                ExpectedDestinations = @(
                    $requirementMetadata.ExpectedDestinations
                )
            })
        }

        New-Item -ItemType Directory -Path $assemblyRoot -Force | Out-Null
        $manifest = [PSCustomObject]@{
            SchemaVersion = '1.0'
            Profile = $plan.Profile
            ModSet = $plan.ModSet
            BuiltAt = Get-Date
            SourceRoot = $plan.StagingRoot
            DeploymentRoot = $plan.DeploymentRoot
            Status = 'Verified'
            HashAlgorithm = 'SHA256'
            PackageCount = $packageResults.Count
            FileCount = $files.Count
            Packages = @($packageResults)
            Files = @($files)
        }
        Write-PwJson -InputObject $manifest -Path $assemblyManifestPath
        $buildSucceeded = $true

        [PSCustomObject]@{
            Profile = $plan.Profile
            ModSet = $plan.ModSet
            Built = $true
            DeployedToGame = $false
            Status = 'Verified'
            ManifestPath = $assemblyManifestPath
            PackageCount = $packageResults.Count
            FileCount = $files.Count
            Packages = @($packageResults)
            Files = @($files)
        }
    }
    finally {
        if (-not $buildSucceeded) {
            foreach ($filePath in $createdDeploymentFiles) {
                if (Test-Path -LiteralPath $filePath -PathType Leaf) {
                    Remove-Item -LiteralPath $filePath -Force
                }
            }
            foreach ($libraryRoot in $createdLibraryRoots) {
                if (
                    Test-Path -LiteralPath $libraryRoot -PathType Container
                ) {
                    Remove-Item -LiteralPath $libraryRoot -Recurse -Force
                }
            }
        }
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

function Test-PwProfileDeploymentAssembly {

    [CmdletBinding()]
    param(
        [string]$Path = (
            Join-Path (Get-PwPaths).Deployment 'assembly-manifest.json'
        )
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $manifest = $null

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $errors.Add("Assembly manifest was not found: $Path")
    }
    else {
        try {
            $manifest = Read-PwJson -Path $Path
        }
        catch {
            $errors.Add($_.Exception.Message)
        }
    }

    $files = @(
        if ($manifest) {
            foreach ($file in @($manifest.Files)) {
                $relativePathValue = (
                    [string]$file.RelativePath
                ).Replace('/', '\')
                if ($relativePathValue -match '^(?i:Pal)\\(.+)$') {
                    $relativePathValue = $Matches[1]
                }
                $fullPath = Join-Path `
                    $manifest.DeploymentRoot `
                    $relativePathValue
                $actualHash = ''
                $status = 'Missing'

                if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
                    $actualHash = (
                        Get-FileHash -LiteralPath $fullPath -Algorithm SHA256
                    ).Hash
                    $status = if ($actualHash -eq [string]$file.Hash) {
                        'Verified'
                    }
                    else {
                        'HashMismatch'
                    }
                }

                if ($status -ne 'Verified') {
                    $errors.Add(
                        "$status assembly file: $($file.RelativePath)"
                    )
                }

                [PSCustomObject]@{
                    CatalogKey = [string]$file.CatalogKey
                    RelativePath = [string]$file.RelativePath
                    ExpectedHash = [string]$file.Hash
                    ActualHash = $actualHash
                    Status = $status
                }
            }
        }
    )

    [PSCustomObject]@{
        ManifestPath = $Path
        Profile = if ($manifest) { [string]$manifest.Profile } else { '' }
        IsValid = ($errors.Count -eq 0)
        VerifiedCount = @($files | Where-Object Status -eq 'Verified').Count
        FileCount = $files.Count
        Errors = @($errors)
        Files = $files
        Manifest = $manifest
    }
}

function Build-PwProfileExperiment {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$ProfileName = (
            (Get-PwWorkshopConfig).Deployment.ActiveProfile
        ),

        [string]$Label = 'Debug',

        [switch]$Apply
    )

    if (-not (Test-PwModIdentifier -Value $Label)) {
        throw "Invalid experiment label '$Label'."
    }

    $plan = Get-PwProfileAssemblyPlan -ProfileName $ProfileName
    $experimentRoot = Join-Path (
        Join-Path (Get-PwPaths).Sandbox 'ProfileExperiments'
    ) (
        '{0}-{1}-{2}' -f (
            Get-Date -Format 'yyyyMMdd-HHmmss'
        ), $ProfileName, $Label
    )

    if (-not $Apply) {
        return [PSCustomObject]@{
            Profile = $ProfileName
            Label = $Label
            ExperimentRoot = $experimentRoot
            PackageCount = $plan.PackageCount
            FileCount = $plan.FileCount
            CanBuild = $plan.CanBuild
            Built = $false
            DeployedToGame = $false
        }
    }

    if (-not $plan.CanBuild) {
        throw 'Experiment build is blocked by unresolved assembly review items.'
    }

    if (-not $PSCmdlet.ShouldProcess(
        $experimentRoot,
        "Build isolated experiment '$Label'"
    )) {
        return $plan
    }

    $palRoot = Join-Path $experimentRoot 'Pal'
    $files = [System.Collections.Generic.List[object]]::new()

    foreach ($package in $plan.Packages) {
        foreach ($component in $package.Components) {
            $sourcePath = Join-Path $plan.StagingRoot (
                $component.RelativePath.Replace('/', '\')
            )
            $relativePath = ([string]$component.RelativePath).Replace('/', '\')
            if ($relativePath -match '^(?i:Pal)\\(.+)$') {
                $relativePath = $Matches[1]
            }
            $destinationPath = Join-Path $palRoot $relativePath
            $destinationDirectory = Split-Path -Parent $destinationPath
            New-Item `
                -ItemType Directory `
                -Path $destinationDirectory `
                -Force |
                Out-Null
            Copy-Item `
                -LiteralPath $sourcePath `
                -Destination $destinationPath `
                -Force `
                -ErrorAction Stop
            $actualHash = (
                Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
            ).Hash

            if ($actualHash -ne [string]$component.Hash) {
                throw "Experiment hash mismatch: $relativePath"
            }

            $files.Add([PSCustomObject]@{
                CatalogKey = $package.CatalogKey
                RelativePath = $relativePath
                Hash = $actualHash
                Status = 'Verified'
            })
        }
    }

    $manifestPath = Join-Path $experimentRoot 'experiment-manifest.json'
    Write-PwJson -InputObject ([PSCustomObject]@{
        SchemaVersion = '1.0'
        Profile = $ProfileName
        ModSet = $plan.ModSet
        Label = $Label
        BuiltAt = Get-Date
        Status = 'Verified'
        DeployedToGame = $false
        FileCount = $files.Count
        Files = @($files)
    }) -Path $manifestPath

    [PSCustomObject]@{
        Profile = $ProfileName
        Label = $Label
        ExperimentRoot = $experimentRoot
        ManifestPath = $manifestPath
        PackageCount = $plan.PackageCount
        FileCount = $files.Count
        Status = 'Verified'
        Built = $true
        DeployedToGame = $false
    }
}

<#
.SYNOPSIS
    Provides the structured workshop dashboard data model.
.DESCRIPTION
    Composes existing read-only workshop providers into one deterministic model
    for terminal, automation, and future integration consumers.
#>

Set-StrictMode -Version Latest

function Get-PwDashboardPropertyValue {

    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        [object]$Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }

    $property = $InputObject.PSObject.Properties[$Name]

    if ($null -eq $property) {
        return $Default
    }

    $property.Value
}

function Get-PwDashboardFirstLine {

    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$InputObject
    )

    $line = @($InputObject) | Select-Object -First 1

    if ($null -eq $line) {
        return ''
    }

    ([string]$line).Trim()
}

function Invoke-PwDashboardGit {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [switch]$AllowFailure
    )

    [object[]]$output = @(& git @Arguments 2>&1)
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $message = (($output | ForEach-Object { [string]$_ }) | Out-String).Trim()

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "Git command failed with exit code $exitCode."
        }

        throw "git $($Arguments -join ' ') failed.`n$message"
    }

    [PSCustomObject]@{
        ExitCode = $exitCode
        Output = @($output | ForEach-Object { [string]$_ })
    }
}

function Get-PwDashboardRepositoryState {

    [CmdletBinding()]
    param()

    $root = Get-PwWorkshopRoot
    $gitPrefix = @('-C', $root)
    $inside = Invoke-PwDashboardGit `
        -Arguments ($gitPrefix + @('rev-parse', '--is-inside-work-tree'))

    if ((Get-PwDashboardFirstLine -InputObject $inside.Output) -ne 'true') {
        throw "Workshop root is not a Git working tree: $root"
    }

    $branchResult = Invoke-PwDashboardGit `
        -Arguments ($gitPrefix + @('branch', '--show-current'))
    $branch = Get-PwDashboardFirstLine -InputObject $branchResult.Output

    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = '(detached)'
    }

    $commitResult = Invoke-PwDashboardGit `
        -Arguments ($gitPrefix + @('rev-parse', 'HEAD'))
    $commit = Get-PwDashboardFirstLine -InputObject $commitResult.Output
    $upstreamResult = Invoke-PwDashboardGit `
        -Arguments (
            $gitPrefix + @(
                'rev-parse',
                '--abbrev-ref',
                '--symbolic-full-name',
                '@{upstream}'
            )
        ) `
        -AllowFailure
    $upstream = if ($upstreamResult.ExitCode -eq 0) {
        Get-PwDashboardFirstLine -InputObject $upstreamResult.Output
    }
    else {
        ''
    }
    $statusResult = Invoke-PwDashboardGit `
        -Arguments (
            $gitPrefix + @('status', '--short', '--untracked-files=all')
        )
    $changes = @(
        $statusResult.Output |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    $stagedCount = 0
    $unstagedCount = 0
    $untrackedCount = 0
    $conflictCount = 0

    foreach ($line in $changes) {
        if ($line.Length -lt 2) {
            continue
        }

        $status = $line.Substring(0, 2)

        if ($status -eq '??') {
            $untrackedCount++
            continue
        }

        if ($status -in @('DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU')) {
            $conflictCount++
        }

        if ($status[0] -ne ' ') {
            $stagedCount++
        }

        if ($status[1] -ne ' ') {
            $unstagedCount++
        }
    }

    $ahead = 0
    $behind = 0

    if (-not [string]::IsNullOrWhiteSpace($upstream)) {
        $relationship = Invoke-PwDashboardGit `
            -Arguments (
                $gitPrefix + @(
                    'rev-list',
                    '--left-right',
                    '--count',
                    "$upstream...HEAD"
                )
            )
        $parts = @(
            (Get-PwDashboardFirstLine -InputObject $relationship.Output) -split
                '\s+'
        )

        if (
            $parts.Count -ne 2 -or
            -not [int]::TryParse($parts[0], [ref]$behind) -or
            -not [int]::TryParse($parts[1], [ref]$ahead)
        ) {
            throw "Unexpected Git ahead/behind output for '$upstream'."
        }
    }

    [PSCustomObject]@{
        Root = $root
        Branch = $branch
        Commit = $commit
        Upstream = $upstream
        HasUpstream = -not [string]::IsNullOrWhiteSpace($upstream)
        Ahead = $ahead
        Behind = $behind
        IsClean = $changes.Count -eq 0
        StagedCount = $stagedCount
        UnstagedCount = $unstagedCount
        UntrackedCount = $untrackedCount
        ConflictCount = $conflictCount
        Changes = @($changes)
    }
}

function Get-PwDashboardProfileState {

    [CmdletBinding()]
    param()

    $configuration = Get-PwWorkshopConfig
    $profileName = [string]$configuration.Deployment.ActiveProfile
    $profile = Get-PwProfile -Name $profileName
    $validation = Test-PwProfile -Name $profileName
    $preview = Get-PwProfileModSetPreview -Name $profileName
    $game = Get-PwDashboardPropertyValue `
        -InputObject $profile `
        -Name Game

    [PSCustomObject]@{
        Name = $profileName
        Description = [string](
            Get-PwDashboardPropertyValue `
                -InputObject $profile `
                -Name Description `
                -Default ''
        )
        Platform = [string](
            Get-PwDashboardPropertyValue `
                -InputObject $game `
                -Name Platform `
                -Default ''
        )
        IsValid = [bool]$validation.IsValid
        IsReady = [bool]$validation.IsReady
        Errors = @($validation.Errors)
        Warnings = @($validation.Warnings)
        ActiveModSet = [string]$preview.ModSet
        SelectedModCount = [int]$preview.ModCount
        SelectedMods = @(
            @($preview.Mods) |
                Sort-Object CatalogKey |
                ForEach-Object {
                    [PSCustomObject]@{
                        CatalogKey = [string]$_.CatalogKey
                        DisplayName = [string]$_.DisplayName
                        InstalledVersion = [string]$_.InstalledVersion
                        ReconciliationStatus = [string]$_.ReconciliationStatus
                        Types = @($_.Types | Sort-Object -Unique)
                    }
                }
        )
    }
}

function Get-PwDashboardCatalogState {

    [CmdletBinding()]
    param()

    $path = Get-PwCatalogManifestPath
    $catalog = Get-PwPersistentModCatalog
    $mods = @(
        @($catalog.Mods) |
            Where-Object { $null -ne $_ } |
            Sort-Object CatalogKey
    )
    $items = @(
        foreach ($mod in $mods) {
            $nexusModIds = @(
                @(
                    Get-PwDashboardPropertyValue `
                        -InputObject $mod `
                        -Name NexusModIds `
                        -Default @()
                ) |
                    Where-Object {
                        $null -ne $_ -and [string]$_ -match '^\d+$'
                    } |
                    ForEach-Object { [int]$_ } |
                    Sort-Object -Unique
            )
            $versions = @(
                Get-PwDashboardPropertyValue `
                    -InputObject $mod `
                    -Name Versions `
                    -Default @()
            )

            [PSCustomObject]@{
                CatalogKey = [string]$mod.CatalogKey
                DisplayName = [string]$mod.DisplayName
                Source = [string](
                    Get-PwDashboardPropertyValue `
                        -InputObject $mod `
                        -Name Source `
                        -Default ''
                )
                Enabled = [bool](
                    Get-PwDashboardPropertyValue `
                        -InputObject $mod `
                        -Name Enabled `
                        -Default $false
                )
                InstalledVersion = [string](
                    Get-PwDashboardPropertyValue `
                        -InputObject $mod `
                        -Name InstalledVersion `
                        -Default ''
                )
                ReconciliationStatus = [string](
                    Get-PwDashboardPropertyValue `
                        -InputObject $mod `
                        -Name ReconciliationStatus `
                        -Default ''
                )
                NexusModIds = $nexusModIds
                HasNexusId = $nexusModIds.Count -gt 0
                Types = @(
                    @(
                        Get-PwDashboardPropertyValue `
                            -InputObject $mod `
                            -Name Types `
                            -Default @()
                    ) |
                        Sort-Object -Unique
                )
                VersionCount = $versions.Count
                PresentArchiveCount = @(
                    $versions |
                        Where-Object {
                            [bool](
                                Get-PwDashboardPropertyValue `
                                    -InputObject $_ `
                                    -Name ArchivePresent `
                                    -Default $false
                            )
                        }
                ).Count
            }
        }
    )
    $sourceCounts = @(
        $items |
            Group-Object Source |
            Sort-Object Name |
            ForEach-Object {
                [PSCustomObject]@{
                    Name = [string]$_.Name
                    Count = [int]$_.Count
                }
            }
    )
    $reconciliationCounts = @(
        $items |
            Group-Object ReconciliationStatus |
            Sort-Object Name |
            ForEach-Object {
                [PSCustomObject]@{
                    Name = [string]$_.Name
                    Count = [int]$_.Count
                }
            }
    )

    [PSCustomObject]@{
        Path = $path
        Exists = Test-Path -LiteralPath $path -PathType Leaf
        SchemaVersion = [string]$catalog.SchemaVersion
        UpdatedAt = $catalog.UpdatedAt
        ModCount = $items.Count
        EnabledCount = @($items | Where-Object Enabled).Count
        WithNexusIdCount = @($items | Where-Object HasNexusId).Count
        WithInstalledVersionCount = @(
            $items |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_.InstalledVersion)
                }
        ).Count
        SourceCounts = $sourceCounts
        ReconciliationCounts = $reconciliationCounts
        Items = $items
    }
}

function Get-PwDashboardDeploymentState {

    [CmdletBinding()]
    param()

    $configuration = Get-PwDeployment
    $assemblyPlan = $null
    $assemblyPlanStatus = 'Unavailable'
    $assemblyPlanError = ''
    $assemblyValidation = $null
    $assemblyValidationStatus = 'Unavailable'
    $assemblyValidationError = ''
    $readiness = $null
    $readinessStatus = 'NotEvaluated'
    $readinessError = ''

    try {
        $assemblyPlan = Get-PwProfileAssemblyPlan `
            -ProfileName $configuration.ActiveProfile
        $assemblyPlanStatus = 'Ready'
    }
    catch {
        $assemblyPlanError = $_.Exception.Message
    }

    try {
        $assemblyValidation = Test-PwProfileDeploymentAssembly
        $assemblyValidationStatus = 'Ready'
    }
    catch {
        $assemblyValidationError = $_.Exception.Message
    }

    if ($configuration.CanDeploy) {
        try {
            $readiness = Test-PwDeploymentReadiness
            $readinessStatus = 'Ready'
        }
        catch {
            $readinessStatus = 'Unavailable'
            $readinessError = $_.Exception.Message
        }
    }

    [PSCustomObject]@{
        ActiveProfile = [string]$configuration.ActiveProfile
        TargetRoot = [string]$configuration.TargetRoot
        GameInstallRoot = [string]$configuration.GameInstallRoot
        GameExecutable = [string]$configuration.GameExecutable
        SavedRoot = [string]$configuration.SavedRoot
        IsReady = [bool]$configuration.IsReady
        CanDeploy = [bool]$configuration.CanDeploy
        Warnings = @($configuration.Warnings)
        AssemblyPlanStatus = $assemblyPlanStatus
        AssemblyPlanError = $assemblyPlanError
        AssemblyPlan = $assemblyPlan
        AssemblyValidationStatus = $assemblyValidationStatus
        AssemblyValidationError = $assemblyValidationError
        AssemblyValidation = $assemblyValidation
        ReadinessStatus = $readinessStatus
        ReadinessError = $readinessError
        Readiness = $readiness
    }
}

function Invoke-PwDashboardSection {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Collector
    )

    try {
        $items = @(& $Collector)
        $data = if ($items.Count -eq 0) {
            $null
        }
        elseif ($items.Count -eq 1) {
            $items[0]
        }
        else {
            @($items)
        }

        [PSCustomObject]@{
            Name = $Name
            Status = 'Ready'
            Error = ''
            Data = $data
        }
    }
    catch {
        [PSCustomObject]@{
            Name = $Name
            Status = 'Unavailable'
            Error = $_.Exception.Message
            Data = $null
        }
    }
}

<#
.SYNOPSIS
    Gets one structured, read-only snapshot of current workshop state.
.DESCRIPTION
    Composes established workshop providers without refreshing remote metadata,
    changing configuration, building output, deploying files, or restoring data.
    Provider failures are isolated so available sections remain consumable.
.PARAMETER GeneratedAt
    Optional snapshot timestamp. Supplying a value supports deterministic tests
    and automation records.
.OUTPUTS
    PSCustomObject containing workshop, repository, profile, catalog, deployment,
    update-cache, and diagnostic sections plus collection status metadata.
#>
function Get-PwWorkshopDashboard {

    [CmdletBinding()]
    param(
        [datetime]$GeneratedAt = (Get-Date).ToUniversalTime()
    )

    $sections = @(
        Invoke-PwDashboardSection `
            -Name Workshop `
            -Collector { Get-PwWorkshopInfo }
        Invoke-PwDashboardSection `
            -Name Repository `
            -Collector { Get-PwDashboardRepositoryState }
        Invoke-PwDashboardSection `
            -Name Profile `
            -Collector { Get-PwDashboardProfileState }
        Invoke-PwDashboardSection `
            -Name Catalog `
            -Collector { Get-PwDashboardCatalogState }
        Invoke-PwDashboardSection `
            -Name Deployment `
            -Collector { Get-PwDashboardDeploymentState }
        Invoke-PwDashboardSection `
            -Name UpdateCache `
            -Collector { Get-PwNexusMetadataCacheInfo }
        Invoke-PwDashboardSection `
            -Name Diagnostics `
            -Collector { Get-PwDiagnostics }
    )
    $sectionsByName = @{}

    foreach ($section in $sections) {
        $sectionsByName[$section.Name] = $section
    }

    $unavailable = @(
        $sections |
            Where-Object Status -ne 'Ready'
    )

    [PSCustomObject]@{
        SchemaVersion = '1.0'
        GeneratedAt = $GeneratedAt.ToUniversalTime()
        Workshop = $sectionsByName['Workshop'].Data
        Repository = $sectionsByName['Repository'].Data
        Profile = $sectionsByName['Profile'].Data
        Catalog = $sectionsByName['Catalog'].Data
        Deployment = $sectionsByName['Deployment'].Data
        UpdateCache = $sectionsByName['UpdateCache'].Data
        Diagnostics = $sectionsByName['Diagnostics'].Data
        Sections = @(
            $sections |
                ForEach-Object {
                    [PSCustomObject]@{
                        Name = [string]$_.Name
                        Status = [string]$_.Status
                        Error = [string]$_.Error
                    }
                }
        )
        ReadySectionCount = @(
            $sections |
                Where-Object Status -eq 'Ready'
        ).Count
        UnavailableSectionCount = $unavailable.Count
        IsComplete = $unavailable.Count -eq 0
        Errors = @(
            $unavailable |
                ForEach-Object {
                    [PSCustomObject]@{
                        Section = [string]$_.Name
                        Message = [string]$_.Error
                    }
                }
        )
    }
}

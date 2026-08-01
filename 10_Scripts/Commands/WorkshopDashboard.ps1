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

function Get-PwWorkshopDashboardSection {

    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Dashboard,

        [Parameter(Mandatory)]
        [string]$Name
    )

    @(
        Get-PwDashboardPropertyValue `
            -InputObject $Dashboard `
            -Name Sections `
            -Default @()
    ) |
        Where-Object Name -eq $Name |
        Select-Object -First 1
}

function Get-PwWorkshopMenuDashboardState {

    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Dashboard
    )

    $profileSection = Get-PwWorkshopDashboardSection `
        -Dashboard $Dashboard `
        -Name Profile
    $repositorySection = Get-PwWorkshopDashboardSection `
        -Dashboard $Dashboard `
        -Name Repository
    $catalogSection = Get-PwWorkshopDashboardSection `
        -Dashboard $Dashboard `
        -Name Catalog
    $deploymentSection = Get-PwWorkshopDashboardSection `
        -Dashboard $Dashboard `
        -Name Deployment
    $cacheSection = Get-PwWorkshopDashboardSection `
        -Dashboard $Dashboard `
        -Name UpdateCache
    $diagnosticsSection = Get-PwWorkshopDashboardSection `
        -Dashboard $Dashboard `
        -Name Diagnostics

    $profile = Get-PwDashboardPropertyValue `
        -InputObject $Dashboard `
        -Name Profile
    $repository = Get-PwDashboardPropertyValue `
        -InputObject $Dashboard `
        -Name Repository
    $catalog = Get-PwDashboardPropertyValue `
        -InputObject $Dashboard `
        -Name Catalog
    $deployment = Get-PwDashboardPropertyValue `
        -InputObject $Dashboard `
        -Name Deployment
    $cache = Get-PwDashboardPropertyValue `
        -InputObject $Dashboard `
        -Name UpdateCache
    $diagnostics = Get-PwDashboardPropertyValue `
        -InputObject $Dashboard `
        -Name Diagnostics

    $profileAvailable = (
        $null -ne $profileSection -and
        $profileSection.Status -eq 'Ready' -and
        $null -ne $profile
    )
    $profileName = if ($profileAvailable) {
        [string](Get-PwDashboardPropertyValue -InputObject $profile -Name Name)
    }
    else {
        'Unavailable'
    }
    $profileStatus = if (-not $profileAvailable) {
        'Unavailable'
    }
    elseif ([bool](Get-PwDashboardPropertyValue -InputObject $profile -Name IsReady)) {
        'Ready'
    }
    elseif ([bool](Get-PwDashboardPropertyValue -InputObject $profile -Name IsValid)) {
        'Needs local paths'
    }
    else {
        'Invalid'
    }
    $activeModSet = if ($profileAvailable) {
        [string](
            Get-PwDashboardPropertyValue `
                -InputObject $profile `
                -Name ActiveModSet `
                -Default '(none)'
        )
    }
    else {
        '(unavailable)'
    }
    $selectedModCount = if ($profileAvailable) {
        [int](
            Get-PwDashboardPropertyValue `
                -InputObject $profile `
                -Name SelectedModCount `
                -Default 0
        )
    }
    else {
        0
    }

    $repositoryAvailable = (
        $null -ne $repositorySection -and
        $repositorySection.Status -eq 'Ready' -and
        $null -ne $repository
    )
    $branch = if ($repositoryAvailable) {
        [string](
            Get-PwDashboardPropertyValue `
                -InputObject $repository `
                -Name Branch `
                -Default '(unknown)'
        )
    }
    else {
        'Unavailable'
    }
    $repositoryStatus = if (-not $repositoryAvailable) {
        'Unavailable'
    }
    elseif ([bool](Get-PwDashboardPropertyValue -InputObject $repository -Name IsClean)) {
        'Clean'
    }
    else {
        $changeCount = @(
            Get-PwDashboardPropertyValue `
                -InputObject $repository `
                -Name Changes `
                -Default @()
        ).Count
        "Changed ($changeCount)"
    }
    $ahead = if ($repositoryAvailable) {
        [int](
            Get-PwDashboardPropertyValue `
                -InputObject $repository `
                -Name Ahead `
                -Default 0
        )
    }
    else {
        0
    }
    $behind = if ($repositoryAvailable) {
        [int](
            Get-PwDashboardPropertyValue `
                -InputObject $repository `
                -Name Behind `
                -Default 0
        )
    }
    else {
        0
    }
    $repositorySync = if (-not $repositoryAvailable) {
        'Unavailable'
    }
    elseif (-not [bool](
        Get-PwDashboardPropertyValue `
            -InputObject $repository `
            -Name HasUpstream `
            -Default $false
    )) {
        'No upstream'
    }
    elseif ($ahead -eq 0 -and $behind -eq 0) {
        'Synchronized'
    }
    else {
        "$ahead ahead / $behind behind"
    }

    $catalogAvailable = (
        $null -ne $catalogSection -and
        $catalogSection.Status -eq 'Ready' -and
        $null -ne $catalog
    )
    $catalogStatus = if ($catalogAvailable) {
        '{0} mods / {1} enabled / {2} Nexus-reviewed' -f @(
            [int](Get-PwDashboardPropertyValue -InputObject $catalog -Name ModCount -Default 0),
            [int](Get-PwDashboardPropertyValue -InputObject $catalog -Name EnabledCount -Default 0),
            [int](Get-PwDashboardPropertyValue -InputObject $catalog -Name WithNexusIdCount -Default 0)
        )
    }
    else {
        'Unavailable'
    }

    $deploymentAvailable = (
        $null -ne $deploymentSection -and
        $deploymentSection.Status -eq 'Ready' -and
        $null -ne $deployment
    )
    $deploymentStatus = if (-not $deploymentAvailable) {
        'Unavailable'
    }
    elseif ([bool](Get-PwDashboardPropertyValue -InputObject $deployment -Name CanDeploy)) {
        'Ready to deploy'
    }
    elseif ([bool](Get-PwDashboardPropertyValue -InputObject $deployment -Name IsReady)) {
        'Configured; deployment blocked'
    }
    else {
        'Needs attention'
    }
    $assemblyStatus = if ($deploymentAvailable) {
        '{0} / verification {1}' -f @(
            [string](Get-PwDashboardPropertyValue -InputObject $deployment -Name AssemblyPlanStatus -Default 'Unavailable'),
            [string](Get-PwDashboardPropertyValue -InputObject $deployment -Name AssemblyValidationStatus -Default 'Unavailable')
        )
    }
    else {
        'Unavailable'
    }

    $cacheAvailable = (
        $null -ne $cacheSection -and
        $cacheSection.Status -eq 'Ready' -and
        $null -ne $cache
    )
    $cacheStatus = if (-not $cacheAvailable) {
        'Unavailable'
    }
    elseif (-not [bool](Get-PwDashboardPropertyValue -InputObject $cache -Name Exists)) {
        'Not created'
    }
    elseif ([bool](Get-PwDashboardPropertyValue -InputObject $cache -Name IsCurrent)) {
        'Current'
    }
    elseif ([bool](Get-PwDashboardPropertyValue -InputObject $cache -Name IsComplete)) {
        'Stale'
    }
    else {
        'Incomplete'
    }

    $diagnosticsAvailable = (
        $null -ne $diagnosticsSection -and
        $diagnosticsSection.Status -eq 'Ready' -and
        $null -ne $diagnostics
    )
    $diagnosticsStatus = if (-not $diagnosticsAvailable) {
        'Unavailable'
    }
    elseif ([bool](Get-PwDashboardPropertyValue -InputObject $diagnostics -Name IsHealthy)) {
        'Healthy'
    }
    else {
        'Needs attention'
    }

    $readySectionCount = [int](
        Get-PwDashboardPropertyValue `
            -InputObject $Dashboard `
            -Name ReadySectionCount `
            -Default 0
    )
    $sectionCount = @(
        Get-PwDashboardPropertyValue `
            -InputObject $Dashboard `
            -Name Sections `
            -Default @()
    ).Count
    $collectionStatus = if ([bool](
        Get-PwDashboardPropertyValue `
            -InputObject $Dashboard `
            -Name IsComplete `
            -Default $false
    )) {
        "Complete ($readySectionCount/$sectionCount)"
    }
    else {
        "Partial ($readySectionCount/$sectionCount)"
    }

    [PSCustomObject]@{
        ProfileName = $profileName
        ProfileStatus = $profileStatus
        ActiveModSet = $activeModSet
        SelectedModCount = $selectedModCount
        Branch = $branch
        RepositoryStatus = $repositoryStatus
        RepositorySync = $repositorySync
        CatalogStatus = $catalogStatus
        DeploymentStatus = $deploymentStatus
        AssemblyStatus = $assemblyStatus
        UpdateCacheStatus = $cacheStatus
        DiagnosticsStatus = $diagnosticsStatus
        CollectionStatus = $collectionStatus
    }
}

function Get-PwWorkshopMenuLayout {

    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Dashboard,

        [string]$Profile = '',

        [string]$EnvironmentStatus = '',

        [ValidateRange(40, 110)]
        [int]$Width = 80,

        [ValidateRange(18, 40)]
        [int]$Height = 24
    )

    $state = Get-PwWorkshopMenuDashboardState -Dashboard $Dashboard

    if ($null -eq $Dashboard -and -not [string]::IsNullOrWhiteSpace($Profile)) {
        $state.ProfileName = $Profile
        $state.ProfileStatus = if (
            [string]::IsNullOrWhiteSpace($EnvironmentStatus)
        ) {
            'Unknown'
        }
        else {
            $EnvironmentStatus
        }
    }

    $border = '+' + ('-' * ($Width - 2)) + '+'
    $content = [System.Collections.Generic.List[object]]::new()
    $content.Add(
        (New-PwWorkshopMenuLine `
            -Text 'PALWORLD MODDING WORKSHOP' `
            -Alignment Center `
            -Color Cyan `
            -Width $Width)
    )
    $content.Add(
        (New-PwWorkshopMenuLine `
            -Text 'Guided workshop operations and current state' `
            -Alignment Center `
            -Color DarkCyan `
            -Width $Width)
    )
    $content.Add(
        (New-PwWorkshopMenuLine `
            -Text ('-' * ($Width - 4)) `
            -Color DarkGray `
            -Width $Width)
    )

    if ($Height -ge 30) {
        $content.Add((New-PwWorkshopMenuLine -Text (
            "Profile    : $($state.ProfileName) | $($state.ProfileStatus) | " +
            "Set: $($state.ActiveModSet) ($($state.SelectedModCount) mods)"
        ) -Width $Width))
        $content.Add((New-PwWorkshopMenuLine -Text (
            "Repository : $($state.Branch) | $($state.RepositoryStatus) | " +
            $state.RepositorySync
        ) -Width $Width))
        $content.Add((New-PwWorkshopMenuLine -Text (
            "Catalog    : $($state.CatalogStatus)"
        ) -Width $Width))
        $content.Add((New-PwWorkshopMenuLine -Text (
            "Deployment : $($state.DeploymentStatus) | Assembly: " +
            $state.AssemblyStatus
        ) -Width $Width))
        $content.Add((New-PwWorkshopMenuLine -Text (
            "Updates    : $($state.UpdateCacheStatus) | Diagnostics: " +
            $state.DiagnosticsStatus
        ) -Width $Width))
        $content.Add((New-PwWorkshopMenuLine -Text (
            "Snapshot   : $($state.CollectionStatus)"
        ) -Color DarkGray -Width $Width))
    }
    elseif ($Height -ge 24) {
        $content.Add((New-PwWorkshopMenuLine -Text (
            "Profile: $($state.ProfileName) ($($state.ProfileStatus)) | " +
            "Repository: $($state.Branch) ($($state.RepositoryStatus))"
        ) -Width $Width))
        $content.Add((New-PwWorkshopMenuLine -Text (
            "Catalog: $($state.CatalogStatus)"
        ) -Width $Width))
        $content.Add((New-PwWorkshopMenuLine -Text (
            "Workshop: $($state.CollectionStatus) | Updates: " +
            "$($state.UpdateCacheStatus) | Diagnostics: " +
            $state.DiagnosticsStatus
        ) -Color DarkGray -Width $Width))
    }
    else {
        $content.Add((New-PwWorkshopMenuLine -Text (
            "$($state.ProfileName): $($state.ProfileStatus) | " +
            "$($state.Branch): $($state.RepositoryStatus) | " +
            $state.CollectionStatus
        ) -Width $Width))
    }

    $content.Add(
        (New-PwWorkshopMenuLine `
            -Text ('-' * ($Width - 4)) `
            -Color DarkGray `
            -Width $Width)
    )

    if ($Height -lt 24) {
        $content.Add((New-PwWorkshopMenuLine `
            -Text ' [1] Catalog  [2] Archives  [3] Staging' `
            -Width $Width))
        $content.Add((New-PwWorkshopMenuLine `
            -Text ' [4] Updates  [5] Compatibility  [6] Mod sets' `
            -Width $Width))
        $content.Add((New-PwWorkshopMenuLine `
            -Text ' [7] Build/deploy  [8] Diagnostics' `
            -Width $Width))
        $content.Add((New-PwWorkshopMenuLine `
            -Text ' [9] Inventory  [0] History' `
            -Width $Width))
        $content.Add((New-PwWorkshopMenuLine `
            -Text ' [H] Current state dashboard  [Q] Exit' `
            -Color Yellow `
            -Width $Width))
    }
    else {
        foreach ($option in @(
            '  [1] View catalog overview and version matches',
            '  [2] View Nexus archive metadata',
            '  [3] View staged UE4SS and ownership snapshot',
            '  [4] Check mod and tool updates',
            '  [5] View compatibility and conflict report',
            '  [6] Manage profile mod sets',
            '  [7] Stage, experiment, build, or deploy',
            '  [8] Run diagnostics',
            '  [9] View known-good installation inventory',
            '  [0] View deployment and restore history'
        )) {
            $content.Add((New-PwWorkshopMenuLine -Text $option -Width $Width))
        }
        $content.Add((New-PwWorkshopMenuLine `
            -Text '  [H] View current state dashboard' `
            -Color Cyan `
            -Width $Width))
        $content.Add((New-PwWorkshopMenuLine `
            -Text '  [Q] Exit' `
            -Color Yellow `
            -Width $Width))
    }

    $content.Add((New-PwWorkshopMenuLine `
        -Text 'Press 0-9, H, or Q.' `
        -Color DarkGray `
        -Width $Width))

    $targetRenderedRows = if ($Height -le 18) {
        $Height
    }
    else {
        $Height - 2
    }
    $extraRows = [math]::Max(0, $targetRenderedRows - ($content.Count + 2))
    $topPadding = [math]::Floor($extraRows / 2)
    $bottomPadding = $extraRows - $topPadding
    $layout = [System.Collections.Generic.List[object]]::new()

    $layout.Add([PSCustomObject]@{
        Text = $border
        Color = [ConsoleColor]::Cyan
    })

    for ($index = 0; $index -lt $topPadding; $index++) {
        $layout.Add((New-PwWorkshopMenuLine -Width $Width))
    }

    foreach ($line in $content) {
        $layout.Add($line)
    }

    for ($index = 0; $index -lt $bottomPadding; $index++) {
        $layout.Add((New-PwWorkshopMenuLine -Width $Width))
    }

    $layout.Add([PSCustomObject]@{
        Text = $border
        Color = [ConsoleColor]::Cyan
    })

    @($layout)
}

function Show-PwWorkshopMenu {

    [CmdletBinding()]
    param()

    $dashboard = try {
        Get-PwWorkshopDashboard
    }
    catch {
        $null
    }
    $terminal = Get-PwWorkshopTerminalSize
    $layout = Get-PwWorkshopMenuLayout `
        -Dashboard $dashboard `
        -Width $terminal.Width `
        -Height $terminal.Height

    foreach ($line in $layout) {
        Write-Host $line.Text -ForegroundColor $line.Color
    }
}

function Show-PwWorkshopDashboard {

    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Dashboard
    )

    if ($null -eq $Dashboard) {
        $Dashboard = Get-PwWorkshopDashboard
    }

    $state = Get-PwWorkshopMenuDashboardState -Dashboard $Dashboard
    $generatedAt = Get-PwDashboardPropertyValue `
        -InputObject $Dashboard `
        -Name GeneratedAt

    Clear-Host
    Write-Host 'PALWORLD MODDING WORKSHOP - CURRENT STATE' -ForegroundColor Cyan
    Write-Host 'Read-only snapshot; no refresh, build, deploy, or repository mutation.' `
        -ForegroundColor DarkGray
    Write-Host ''

    if ($null -ne $generatedAt) {
        Write-Host (
            'Generated : ' + ([datetime]$generatedAt).ToLocalTime().ToString('u')
        )
    }
    Write-Host "Snapshot  : $($state.CollectionStatus)"
    Write-Host "Profile   : $($state.ProfileName) | $($state.ProfileStatus)"
    Write-Host (
        "Mod set   : $($state.ActiveModSet) | " +
        "$($state.SelectedModCount) selected mods"
    )
    Write-Host (
        "Repository: $($state.Branch) | $($state.RepositoryStatus) | " +
        $state.RepositorySync
    )
    Write-Host "Catalog   : $($state.CatalogStatus)"
    Write-Host "Deployment: $($state.DeploymentStatus)"
    Write-Host "Assembly  : $($state.AssemblyStatus)"
    Write-Host "Updates   : $($state.UpdateCacheStatus)"
    Write-Host "Diagnostics: $($state.DiagnosticsStatus)"
    Write-Host ''

    $sections = @(
        Get-PwDashboardPropertyValue `
            -InputObject $Dashboard `
            -Name Sections `
            -Default @()
    )

    if ($sections.Count -gt 0) {
        $sectionText = (
            $sections |
                Select-Object Name, Status, Error |
                Format-Table -AutoSize -Wrap |
                Out-String -Width (Get-PwWorkshopTerminalSize).Width
        ).TrimEnd()
        Write-Host $sectionText
    }

    $errors = @(
        Get-PwDashboardPropertyValue `
            -InputObject $Dashboard `
            -Name Errors `
            -Default @()
    )

    if ($errors.Count -gt 0) {
        Write-Host ''
        Write-Host 'Unavailable sections:' -ForegroundColor Yellow
        foreach ($errorItem in $errors) {
            Write-Host (
                " - $($errorItem.Section): $($errorItem.Message)"
            ) -ForegroundColor Yellow
        }
    }
}

function Invoke-PwWorkshopDashboardMenuView {

    [CmdletBinding()]
    param()

    try {
        Show-PwWorkshopDashboard -Dashboard (Get-PwWorkshopDashboard)
    }
    catch {
        Clear-Host
        Write-Host 'Workshop dashboard is unavailable.' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ''
    $selection = Read-Host '[B] Back, Enter to return, or Q to quit'

    if (Test-PwWorkshopQuitSelection $selection) {
        return 'Q'
    }

    '__RESIZE__'
}

function Read-PwWorkshopMenuSelection {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$RenderedTerminal
    )

    try {
        $null = [Console]::KeyAvailable
    }
    catch {
        $fallbackSelection = (Read-Host ' Select').Trim().ToUpperInvariant()

        if ($fallbackSelection -eq 'H') {
            return Invoke-PwWorkshopDashboardMenuView
        }

        return $fallbackSelection
    }

    while ($true) {
        $currentTerminal = Get-PwWorkshopTerminalSize

        if (
            $currentTerminal.Width -ne $RenderedTerminal.Width -or
            $currentTerminal.Height -ne $RenderedTerminal.Height
        ) {
            return '__RESIZE__'
        }

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            $selection = $key.KeyChar.ToString().ToUpperInvariant()

            if ($selection -eq 'H') {
                return Invoke-PwWorkshopDashboardMenuView
            }

            if ($selection -in @(
                '0', '1', '2', '3', '4', '5',
                '6', '7', '8', '9', 'Q'
            )) {
                return $selection
            }
        }

        Start-Sleep -Milliseconds 100
    }
}

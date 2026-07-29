<#
.SYNOPSIS
    Provides the interactive Palworld Modding Workshop menu.
#>

Set-StrictMode -Version Latest

function Get-PwWorkshopTerminalSize {

    [CmdletBinding()]
    param()

    try {
        $terminalWidth = [Console]::WindowWidth
        $terminalHeight = [Console]::WindowHeight
    }
    catch {
        $terminalWidth = 80
        $terminalHeight = 24
    }

    if ($terminalWidth -lt 1) {
        $terminalWidth = 80
    }

    if ($terminalHeight -lt 1) {
        $terminalHeight = 24
    }

    [PSCustomObject]@{
        # Leave one terminal column unused to prevent automatic line wrapping.
        Width = [math]::Max(40, [math]::Min(110, $terminalWidth - 1))
        Height = [math]::Max(18, [math]::Min(40, $terminalHeight))
    }
}

function New-PwWorkshopMenuLine {

    [CmdletBinding()]
    param(
        [string]$Text = '',

        [ValidateSet('Left', 'Center')]
        [string]$Alignment = 'Left',

        [ConsoleColor]$Color = [ConsoleColor]::Gray,

        [Parameter(Mandatory)]
        [ValidateRange(40, 110)]
        [int]$Width
    )

    $contentWidth = $Width - 4
    $content = $Text

    if ($content.Length -gt $contentWidth) {
        $content = $content.Substring(0, $contentWidth - 3) + '...'
    }

    $leftPadding = 0

    if ($Alignment -eq 'Center') {
        $leftPadding = [math]::Floor(
            ($contentWidth - $content.Length) / 2
        )
    }

    $rightPadding = $contentWidth - $content.Length - $leftPadding

    [PSCustomObject]@{
        Text = (
            '| ' +
            (' ' * $leftPadding) +
            $content +
            (' ' * $rightPadding) +
            ' |'
        )
        Color = $Color
    }
}

function Get-PwWorkshopMenuLayout {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Profile,

        [Parameter(Mandatory)]
        [string]$EnvironmentStatus,

        [ValidateRange(40, 110)]
        [int]$Width = 80,

        [ValidateRange(18, 40)]
        [int]$Height = 24
    )

    $border = '+' + ('-' * ($Width - 2)) + '+'
    $content = @(
        New-PwWorkshopMenuLine `
            -Text 'PALWORLD MODDING WORKSHOP' `
            -Alignment Center `
            -Color Cyan `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text 'Sprint 4 - Catalog, Library, and Compatibility' `
            -Alignment Center `
            -Color DarkCyan `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text ('-' * ($Width - 4)) `
            -Color DarkGray `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text "Active profile : $Profile" `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text "Environment    : $EnvironmentStatus" `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text ('-' * ($Width - 4)) `
            -Color DarkGray `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [1] View catalog overview and version matches' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [2] View Nexus archive metadata' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [3] View staged UE4SS and ownership snapshot' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [4] Check mod and tool updates' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [5] View compatibility and conflict report' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [6] Manage profile mod sets' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [7] Stage, experiment, build, or deploy' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [8] Run diagnostics' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [9] View known-good installation inventory' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [0] View deployment and restore history' `
            -Width $Width
        New-PwWorkshopMenuLine -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [Q] Exit' `
            -Color Yellow `
            -Width $Width
        New-PwWorkshopMenuLine -Width $Width
        New-PwWorkshopMenuLine `
            -Text 'Press 0-9 or Q.' `
            -Color DarkGray `
            -Width $Width
    )

    if ($Height -lt 24) {
        $content = @(
            New-PwWorkshopMenuLine `
                -Text 'PALWORLD MODDING WORKSHOP' `
                -Alignment Center `
                -Color Cyan `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text "Profile: $Profile | Environment: $EnvironmentStatus" `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text ('-' * ($Width - 4)) `
                -Color DarkGray `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text ' [1] Catalog  [2] Archives  [3] Staging' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text ' [4] Updates  [5] Compatibility  [6] Mod sets' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text ' [7] Stage, experiment, build, or deploy' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text ' [8] Diagnostics  [9] Inventory  [0] History' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text ' [Q] Exit' `
                -Color Yellow `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text 'Press 0-9 or Q.' `
                -Color DarkGray `
                -Width $Width
        )
    }
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

    $layout.Add(
        [PSCustomObject]@{
            Text = $border
            Color = [ConsoleColor]::Cyan
        }
    )

    for ($index = 0; $index -lt $topPadding; $index++) {
        $layout.Add((New-PwWorkshopMenuLine -Width $Width))
    }

    foreach ($line in $content) {
        $layout.Add($line)
    }

    for ($index = 0; $index -lt $bottomPadding; $index++) {
        $layout.Add((New-PwWorkshopMenuLine -Width $Width))
    }

    $layout.Add(
        [PSCustomObject]@{
            Text = $border
            Color = [ConsoleColor]::Cyan
        }
    )

    @($layout)
}

function Show-PwWorkshopMenu {

    [CmdletBinding()]
    param()

    $configuration = Get-PwWorkshopConfig
    $environment = Test-PwEnvironment
    $environmentStatus = if ($environment.IsReady) {
        'Ready'
    }
    else {
        'Needs attention'
    }
    $terminal = Get-PwWorkshopTerminalSize
    $layout = Get-PwWorkshopMenuLayout `
        -Profile $configuration.Deployment.ActiveProfile `
        -EnvironmentStatus $environmentStatus `
        -Width $terminal.Width `
        -Height $terminal.Height

    foreach ($line in $layout) {
        Write-Host $line.Text -ForegroundColor $line.Color
    }
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
        return Read-Host ' Select'
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

            if ($selection -in @('1', '2', '3', '4', '5', '6', '7', '8', 'H', 'Q')) {
                return $selection
            }
        }

        Start-Sleep -Milliseconds 100
    }
}

function Test-PwWorkshopQuitSelection {

    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Selection
    )

    (
        -not [string]::IsNullOrWhiteSpace($Selection) -and
        $Selection.Trim().Equals(
            'Q',
            [System.StringComparison]::OrdinalIgnoreCase
        )
    )
}

function Test-PwWorkshopBackSelection {

    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Selection
    )

    (
        -not [string]::IsNullOrWhiteSpace($Selection) -and
        $Selection.Trim().Equals(
            'B',
            [System.StringComparison]::OrdinalIgnoreCase
        )
    )
}

function Show-PwWorkshopPagedTable {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [object[]]$Rows = @(),

        [Parameter(Mandatory)]
        [object[]]$Properties,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Page = 1
    )

    $terminal = Get-PwWorkshopTerminalSize
    $pageSize = [math]::Max(4, $terminal.Height - 10)
    $rowCount = @($Rows).Count
    $pageCount = [math]::Max(
        1,
        [math]::Ceiling($rowCount / [double]$pageSize)
    )
    $currentPage = [math]::Max(1, [math]::Min($Page, $pageCount))
    $firstIndex = ($currentPage - 1) * $pageSize
    $pageRows = @(
        if ($rowCount -gt 0) {
            $lastIndex = [math]::Min(
                $firstIndex + $pageSize - 1,
                $rowCount - 1
            )
            $Rows[$firstIndex..$lastIndex]
        }
    )

    Clear-Host
    Write-Host $Title -ForegroundColor Cyan
    Write-Host (
        "Page $currentPage of $pageCount | " +
            "$rowCount item$(if ($rowCount -eq 1) { '' } else { 's' })"
    ) -ForegroundColor DarkGray
    Write-Host ''

    if ($pageRows.Count -eq 0) {
        Write-Host 'No items to display.' -ForegroundColor DarkGray
    }
    else {
        $formatted = (
            $pageRows |
                Select-Object -Property $Properties |
                Format-Table -AutoSize |
                Out-String -Width $terminal.Width
        ).TrimEnd()
        Write-Host $formatted
    }

    [PSCustomObject]@{
        Page = $currentPage
        PageCount = [int]$pageCount
        PageSize = $pageSize
        RowCount = $rowCount
        Rows = $pageRows
        Width = $terminal.Width
        Height = $terminal.Height
    }
}

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

    $currentPage = $Page

    while ($true) {
        $view = Show-PwWorkshopPagedTable `
            -Title $Title `
            -Rows $Rows `
            -Properties $Properties `
            -Page $currentPage
        $navigation = @()
        if ($view.Page -gt 1) {
            $navigation += '[P] Previous'
        }
        if ($view.Page -lt $view.PageCount) {
            $navigation += '[N] Next'
        }

        Write-Host ''
        if ($navigation.Count -gt 0) {
            Write-Host ($navigation -join '  ') -ForegroundColor DarkGray
        }

        $selection = Read-Host $Prompt
        if ($selection -match '^(?i:N)$' -and $view.Page -lt $view.PageCount) {
            $currentPage = $view.Page + 1
            continue
        }
        if ($selection -match '^(?i:P)$' -and $view.Page -gt 1) {
            $currentPage = $view.Page - 1
            continue
        }

        return $selection
    }
}

function Show-PwCatalogSummary {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Catalog
    )

    $Catalog |
        Select-Object `
            ModCount,
            ArchiveCount,
            MatchedModCount,
            MissingArchiveCount,
            ArchiveOnlyCount,
            ModsJsonValid |
        Format-List

    Write-Host 'Catalog status:'
    $Catalog.Mods |
        Group-Object ArchiveMatchStatus |
        Sort-Object Name |
        Select-Object `
            @{Name = 'Status'; Expression = { $_.Name }},
            Count |
        Format-Table -AutoSize

    if ($Catalog.Warnings.Count -gt 0) {
        Write-Host 'Warning summary:' -ForegroundColor Yellow
        $Catalog.Warnings |
            ForEach-Object {
                if ($_ -like 'No surviving archive matches*') {
                    'Missing archive'
                }
                elseif ($_ -like 'Archive has no loose staging match*') {
                    'Archive-only'
                }
                elseif ($_ -like '*malformed JSON*') {
                    'Malformed metadata'
                }
                else {
                    'Other'
                }
            } |
            Group-Object |
            Sort-Object Name |
            Select-Object `
                @{Name = 'Category'; Expression = { $_.Name }},
                Count |
            Format-Table -AutoSize
    }
}

function Show-PwCatalogMods {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Catalog
    )

    $Catalog.Mods |
        Select-Object `
            Name,
            Enabled,
            ArchiveMatchStatus,
            LatestCandidateVersion,
            Types |
        Format-Table -AutoSize
}

function Show-PwCatalogWarnings {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Catalog
    )

    if ($Catalog.Warnings.Count -eq 0) {
        Write-Host 'No catalog warnings.'
        return
    }

    Write-Host 'Catalog warnings:' -ForegroundColor Yellow

    for ($index = 0; $index -lt $Catalog.Warnings.Count; $index++) {
        Write-Host (
            " {0,2}. {1}" -f ($index + 1), $Catalog.Warnings[$index]
        ) -ForegroundColor Yellow
    }
}

function Show-PwUpdateReport {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Updates
    )

    $Updates |
        Select-Object `
            Name,
            NexusModId,
            LocalVersion,
            RemoteVersion,
            Status |
        Format-Table -AutoSize
}

function Get-PwCompatibilityDisplayRows {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Compatibility
    )

    @(
        $Compatibility.DuplicateArchives | ForEach-Object {
            [PSCustomObject]@{
                Category = 'Duplicate archive'
                Name = $_.ArchiveHash
                Details = (
                    (@($_.CatalogKeys) -join ', ') +
                    ' | ' +
                    (@($_.Versions) -join ', ')
                )
            }
        }
        $Compatibility.MixedPackages | ForEach-Object {
            [PSCustomObject]@{
                Category = 'Mixed package'
                Name = $_.DisplayName
                Details = (
                    (@($_.PackageTypes) -join ', ') +
                    " | $($_.ComponentCount) components"
                )
            }
        }
        $Compatibility.VariantWarnings | ForEach-Object {
            [PSCustomObject]@{
                Category = 'Variant'
                Name = $_.DisplayName
                Details = (
                    (@($_.Platforms) -join ', ') +
                    ' | ' +
                    (@($_.PlayModes) -join ', ')
                )
            }
        }
    )
}

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

    switch ($Action) {
        'Summary' {
            return Get-PwWorkshopInfo
        }
        'Catalog' {
            return Get-PwModCatalog
        }
        'CatalogPlan' {
            return Get-PwModCatalogSyncPlan
        }
        'CatalogMetadata' {
            return @(Get-PwNexusCatalogMetadataReport)
        }
        'StagingReconciliation' {
            return Get-PwStagingReconciliation
        }
        'Archives' {
            return @(Get-PwNexusArchiveMetadata)
        }
        'Staging' {
            return @(Get-PwStagedModSnapshot)
        }
        'Updates' {
            return @(Get-PwModUpdateReport)
        }
        'SourceUpdates' {
            return @(Get-PwSourceUpdateReport)
        }
        'Diagnostics' {
            return Get-PwDiagnostics
        }
        'Inventory' {
            return @(Get-PwInstallationInventory)
        }
        'History' {
            return @(Get-PwDeploymentHistory)
        }
    }
}

<#
.SYNOPSIS
    Starts the one-command workshop interface.
.DESCRIPTION
    Opens an interactive menu over safe workshop commands. Sprint 4.1 begins
    with read-only catalog, archive, staging, diagnostic, inventory, and history
    views. Additional reviewed actions will be added as Sprint 4 progresses.
.PARAMETER Action
    Optional non-interactive action for scripting and testing.
.PARAMETER NoClear
    Prevents clearing the terminal between menu screens.
#>
function Start-PwWorkshop {

    [CmdletBinding()]
    param(
        [ValidateSet(
            'Menu',
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
        [string]$Action = 'Menu',

        [switch]$NoClear
    )

    Initialize-PwWorkshop | Out-Null

    if ($Action -ne 'Menu') {
        return Invoke-PwWorkshopMenuAction -Action $Action
    }

    $running = $true

    while ($running) {
        $quitRequested = $false
        $skipReturnPrompt = $false

        if (-not $NoClear) {
            Clear-Host
        }

        $renderedTerminal = Get-PwWorkshopTerminalSize
        Show-PwWorkshopMenu
        $selection = Read-PwWorkshopMenuSelection `
            -RenderedTerminal $renderedTerminal

        if ($selection -eq '__RESIZE__') {
            continue
        }

        if (-not $NoClear) {
            Clear-Host
        }

        switch ($selection.ToUpperInvariant()) {
            '1' {
                $skipReturnPrompt = $true
                $catalogMenuActive = $true

                while ($catalogMenuActive) {
                    $catalog = Invoke-PwWorkshopMenuAction -Action Catalog
                    Show-PwCatalogSummary -Catalog $catalog
                    $catalogChoice = Read-Host (
                        '[L] List mods, [W] Warnings, [S] Sync, ' +
                            '[R] Remote metadata, [E] Edit identity, ' +
                            '[G] Staging groups, [B] Back, ' +
                            'Enter to return, or Q to quit'
                    )

                    if (Test-PwWorkshopQuitSelection $catalogChoice) {
                        $quitRequested = $true
                        break
                    }

                    if (
                        [string]::IsNullOrWhiteSpace($catalogChoice) -or
                        (Test-PwWorkshopBackSelection $catalogChoice)
                    ) {
                        $catalogMenuActive = $false
                        break
                    }

                    if ($catalogChoice -match '^(?i:L)$') {
                        $listChoice = Read-PwWorkshopPagedTable `
                            -Title 'Catalog Mods' `
                            -Rows @($catalog.Mods) `
                            -Properties @(
                                'Name',
                                'Enabled',
                                'ArchiveMatchStatus',
                                'LatestCandidateVersion',
                                'Types'
                            ) `
                            -Prompt '[B] Back, Enter to return, or Q to quit'
                        if (Test-PwWorkshopQuitSelection $listChoice) {
                            $quitRequested = $true
                            break
                        }
                        continue
                    }

                    if ($catalogChoice -match '^(?i:W)$') {
                        $warningRows = @(
                            for (
                                $warningIndex = 0
                                $warningIndex -lt $catalog.Warnings.Count
                                $warningIndex++
                            ) {
                                [PSCustomObject]@{
                                    '#' = $warningIndex + 1
                                    Warning = $catalog.Warnings[$warningIndex]
                                }
                            }
                        )
                        $warningChoice = Read-PwWorkshopPagedTable `
                            -Title 'Catalog Warnings' `
                            -Rows $warningRows `
                            -Properties @('#', 'Warning') `
                            -Prompt '[B] Back, Enter to return, or Q to quit'
                        if (Test-PwWorkshopQuitSelection $warningChoice) {
                            $quitRequested = $true
                            break
                        }
                        continue
                    }

                    if ($catalogChoice -match '^(?i:S)$') {
                        $plan = Invoke-PwWorkshopMenuAction -Action CatalogPlan
                        $plan |
                            Select-Object `
                                Path,
                                HasChanges,
                                ExistingModCount,
                                ProposedModCount,
                                NeedsMetadataCount |
                            Format-List
                        $apply = Read-Host (
                            '[A] Apply this catalog sync, [B] Back, ' +
                                'or Q to quit'
                        )

                        if (Test-PwWorkshopQuitSelection $apply) {
                            $quitRequested = $true
                            break
                        }

                        if (Test-PwWorkshopBackSelection $apply) {
                            continue
                        }

                        if ($apply -match '^(?i:A)$') {
                            Update-PwModCatalog -Confirm:$false |
                                Select-Object `
                                    Path,
                                    HasChanges,
                                    ProposedModCount,
                                    NeedsMetadataCount |
                                Format-List
                        }

                        continue
                    }

                    if ($catalogChoice -match '^(?i:R)$') {
                        try {
                            $metadata = @(
                                Invoke-PwWorkshopMenuAction `
                                    -Action CatalogMetadata
                            )
                            $applyMetadata = Read-PwWorkshopPagedTable `
                                -Title 'Remote Catalog Metadata' `
                                -Rows $metadata `
                                -Properties @(
                                    'CatalogKey',
                                    'NexusModId',
                                    'RemoteName',
                                    'RemoteVersion',
                                    'NameMatch',
                                    'Status'
                                ) `
                                -Prompt (
                                    '[A] Store metadata, [V] Verify review item, ' +
                                        '[B] Back, or Q to quit'
                                )

                            if (Test-PwWorkshopQuitSelection $applyMetadata) {
                                $quitRequested = $true
                                break
                            }

                            if (Test-PwWorkshopBackSelection $applyMetadata) {
                                continue
                            }

                            if ($applyMetadata -match '^(?i:A)$') {
                                Update-PwNexusCatalogMetadata -Confirm:$false |
                                    Select-Object `
                                        CatalogKey,
                                        NexusModId,
                                        NameMatch,
                                        Status |
                                    Format-Table -AutoSize
                                continue
                            }

                            if ($applyMetadata -match '^(?i:V)$') {
                                $reviewItems = @(
                                    $metadata |
                                        Where-Object Status -eq 'ReviewIdentity'
                                )

                                if ($reviewItems.Count -eq 0) {
                                    Write-Host (
                                        'There are no ReviewIdentity records.'
                                    )
                                }
                                else {
                                    $reviewRows = @(
                                        $reviewItems |
                                        Select-Object `
                                            @{Name = '#'; Expression = {
                                                1 + $reviewItems.IndexOf($_)
                                            }},
                                            CatalogKey,
                                            InstallNames,
                                            NexusModId,
                                            RemoteName,
                                            RemoteVersion
                                    )
                                    $reviewKey = Read-PwWorkshopPagedTable `
                                        -Title 'Identity Review Items' `
                                        -Rows $reviewRows `
                                        -Properties @(
                                            '#',
                                            'CatalogKey',
                                            'InstallNames',
                                            'NexusModId',
                                            'RemoteName',
                                            'RemoteVersion'
                                        ) `
                                        -Prompt (
                                            'Review # to inspect, [B] Back, ' +
                                                'or Q to quit'
                                        )

                                    if (
                                        Test-PwWorkshopQuitSelection $reviewKey
                                    ) {
                                        $quitRequested = $true
                                        break
                                    }

                                    if (
                                        Test-PwWorkshopBackSelection $reviewKey
                                    ) {
                                        continue
                                    }

                                    if (
                                        $reviewKey -match '^\d+$'
                                    ) {
                                        $reviewIndex = [int]$reviewKey - 1
                                        $review = if (
                                            $reviewIndex -ge 0 -and
                                            $reviewIndex -lt $reviewItems.Count
                                        ) {
                                            $reviewItems[$reviewIndex]
                                        }
                                        else {
                                            $null
                                        }

                                        if (-not $review) {
                                            Write-Host (
                                                'Review number was not found.'
                                            ) -ForegroundColor Yellow
                                        }
                                        else {
                                            $review |
                                                Select-Object `
                                                    CatalogKey,
                                                    InstallNames,
                                                    NexusModId,
                                                    RemoteName,
                                                    RemoteVersion,
                                                    Summary |
                                                Format-List

                                            if ($review.GitSources.Count -gt 0) {
                                                Write-Host 'GitHub sources:'
                                                $review.GitSources |
                                                    Select-Object `
                                                        Repository,
                                                        SourceUrl |
                                                    Format-Table -AutoSize
                                            }

                                            $verify = Read-Host (
                                                '[A] Approve this as a reviewed alias, [B] Back, ' +
                                                    'or Q to quit'
                                            )

                                            if (
                                                Test-PwWorkshopQuitSelection `
                                                    $verify
                                            ) {
                                                $quitRequested = $true
                                                break
                                            }

                                            if (
                                                Test-PwWorkshopBackSelection `
                                                    $verify
                                            ) {
                                                continue
                                            }

                                            if ($verify -match '^(?i:A)$') {
                                                Set-PwModCatalogMetadata `
                                                    -CatalogKey $review.CatalogKey `
                                                    -InstallName $review.RemoteName `
                                                    -NexusModId $review.NexusModId `
                                                    -ReplaceNexusModIds `
                                                    -Confirm:$false |
                                                    Select-Object `
                                                        CatalogKey,
                                                        DisplayName,
                                                        InstallNames,
                                                        NexusModIds,
                                                        ReconciliationStatus |
                                                    Format-List
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        catch {
                            Write-Host $_.Exception.Message `
                                -ForegroundColor Red
                        }

                        continue
                    }

                    if ($catalogChoice -match '^(?i:E)$') {
                        try {
                            $persistentCatalog = Get-PwPersistentModCatalog
                            $catalogEntries = @($persistentCatalog.Mods)
                            $catalogRows = @(
                                $catalogEntries |
                                Select-Object `
                                    @{Name = '#'; Expression = {
                                        1 + $catalogEntries.IndexOf($_)
                                    }},
                                    CatalogKey,
                                    DisplayName,
                                    @{Name = 'NexusIds'; Expression = {
                                        @($_.NexusModIds) -join ','
                                    }},
                                    InstalledVersion,
                                    ReconciliationStatus
                            )
                            $catalogChoice = Read-PwWorkshopPagedTable `
                                -Title 'Edit Catalog Identity' `
                                -Rows $catalogRows `
                                -Properties @(
                                    '#',
                                    'CatalogKey',
                                    'DisplayName',
                                    'NexusIds',
                                    'InstalledVersion',
                                    'ReconciliationStatus'
                                ) `
                                -Prompt 'Enter # to edit, [B] Back, or Q to quit'

                            if (Test-PwWorkshopQuitSelection $catalogChoice) {
                                $quitRequested = $true
                                break
                            }

                            if (Test-PwWorkshopBackSelection $catalogChoice) {
                                continue
                            }

                            if ($catalogChoice -match '^\d+$') {
                                $catalogIndex = [int]$catalogChoice - 1
                                if (
                                    $catalogIndex -lt 0 -or
                                    $catalogIndex -ge $catalogEntries.Count
                                ) {
                                    Write-Host 'Catalog number was not found.' `
                                        -ForegroundColor Yellow
                                }
                                else {
                                    $record = $catalogEntries[$catalogIndex]
                                    $nexusId = Read-Host (
                                        'Nexus mod ID (Enter to keep current, ' +
                                            '[B] Back)'
                                    )
                                    $displayName = Read-Host (
                                        'Display name (Enter to keep current, ' +
                                            '[B] Back)'
                                    )
                                    $installedVersion = Read-Host (
                                        'Installed version (Enter to keep current, ' +
                                            '[B] Back)'
                                    )
                                    $installName = Read-Host (
                                        'Install/component alias (Enter to keep current, ' +
                                            '[B] Back)'
                                    )
                                    $identity = $null

                                    if (
                                        (Test-PwWorkshopBackSelection $nexusId) -or
                                        (Test-PwWorkshopBackSelection $displayName) -or
                                        (Test-PwWorkshopBackSelection $installedVersion) -or
                                        (Test-PwWorkshopBackSelection $installName)
                                    ) {
                                        continue
                                    }

                                    if ($nexusId -match '^\d+$') {
                                        $identity = Get-PwNexusModIdentity `
                                            -ModId ([int]$nexusId) `
                                            -InstallNames @($record.InstallNames)
                                        $identity |
                                            Select-Object `
                                                NexusModId,
                                                Name,
                                                Version,
                                                NameMatch,
                                                NexusUrl |
                                            Format-List

                                        if ($identity.GitSources.Count -gt 0) {
                                            Write-Host 'GitHub sources:'
                                            $identity.GitSources |
                                                Select-Object `
                                                    Repository,
                                                    ReleaseTag,
                                                    SourceUrl |
                                                Format-Table -AutoSize
                                        }
                                    }
                                    elseif (
                                        -not [string]::IsNullOrWhiteSpace($nexusId)
                                    ) {
                                        throw 'Nexus mod ID must be numeric.'
                                    }

                                    $confirmIdentity = Read-Host (
                                        '[A] Apply reviewed identity fields, ' +
                                            '[B] Back, or Q to quit'
                                    )

                                    if (
                                        Test-PwWorkshopQuitSelection `
                                            $confirmIdentity
                                    ) {
                                        $quitRequested = $true
                                        break
                                    }

                                    if (
                                        Test-PwWorkshopBackSelection `
                                            $confirmIdentity
                                    ) {
                                        continue
                                    }

                                    if ($confirmIdentity -match '^(?i:A)$') {
                                        $parameters = @{
                                            CatalogKey = $record.CatalogKey
                                            Confirm = $false
                                        }

                                        if ($identity) {
                                            $parameters.NexusModId = (
                                                $identity.NexusModId
                                            )
                                            $parameters.ReplaceNexusModIds = $true
                                        }

                                        if (
                                            -not [string]::IsNullOrWhiteSpace(
                                                $displayName
                                            )
                                        ) {
                                            $parameters.DisplayName = $displayName
                                        }

                                        if (
                                            -not [string]::IsNullOrWhiteSpace(
                                                $installedVersion
                                            )
                                        ) {
                                            $parameters.InstalledVersion = (
                                                $installedVersion
                                            )
                                        }

                                        if (
                                            -not [string]::IsNullOrWhiteSpace(
                                                $installName
                                            )
                                        ) {
                                            $parameters.ComponentName = $installName
                                        }

                                        if ($parameters.Count -eq 2) {
                                            Write-Host 'No changes were entered.' `
                                                -ForegroundColor Yellow
                                        }
                                        else {
                                            Set-PwModCatalogMetadata @parameters |
                                                Select-Object `
                                                    CatalogKey,
                                                    DisplayName,
                                                    NexusModIds,
                                                    InstalledVersion,
                                                    InstallNames,
                                                    ComponentNames,
                                                    ReconciliationStatus |
                                                Format-List
                                        }
                                    }
                                }
                            }
                        }
                        catch {
                            Write-Host $_.Exception.Message `
                                -ForegroundColor Red
                        }

                        continue
                    }

                    if ($catalogChoice -match '^(?i:G)$') {
                        $reconciliation = Invoke-PwWorkshopMenuAction `
                            -Action StagingReconciliation
                        $groupPage = 1
                        $openOwnership = $false

                        while ($true) {
                            $groupView = Show-PwWorkshopPagedTable `
                                -Title 'Staging Component Ownership' `
                                -Rows @($reconciliation.Groups) `
                                -Properties @(
                                    'DisplayName',
                                    @{
                                        Name = 'Types'
                                        Expression = {
                                            @($_.PackageTypes) -join ', '
                                        }
                                    },
                                    'ComponentCount',
                                    'IsMixedPackage'
                                ) `
                                -Page $groupPage
                            Write-Host ''
                            Write-Host (
                                "$($reconciliation.MatchedComponentCount) of " +
                                    "$($reconciliation.ComponentCount) components " +
                                    "matched | $($reconciliation.MixedPackageCount) " +
                                    "mixed packages | " +
                                    "$($reconciliation.ReviewItemCount) to review"
                            ) -ForegroundColor DarkGray
                            $groupChoice = Read-Host (
                                '[N] Next, [P] Previous, [O] Ownership review, ' +
                                    '[B] Back, or Q to quit'
                            )

                            if (Test-PwWorkshopQuitSelection $groupChoice) {
                                $quitRequested = $true
                                break
                            }

                            if (Test-PwWorkshopBackSelection $groupChoice) {
                                break
                            }

                            if ($groupChoice -match '^(?i:N)$') {
                                $groupPage = [math]::Min(
                                    $groupView.Page + 1,
                                    $groupView.PageCount
                                )
                                continue
                            }

                            if ($groupChoice -match '^(?i:P)$') {
                                $groupPage = [math]::Max(
                                    1,
                                    $groupView.Page - 1
                                )
                                continue
                            }

                            if ($groupChoice -match '^(?i:O)$') {
                                $openOwnership = $true
                                break
                            }
                        }

                        if ($quitRequested) {
                            break
                        }

                        if (-not $openOwnership) {
                            continue
                        }

                        if ($reconciliation.ReviewItemCount -gt 0) {
                            $reviewItems = @($reconciliation.ReviewItems)
                            $numberedReviewItems = @(
                                $reviewItems |
                                Select-Object `
                                    @{Name = '#'; Expression = {
                                        1 + $reviewItems.IndexOf($_)
                                    }},
                                    OwnerName,
                                    SourceArea,
                                    PackageType,
                                    RelativePath
                            )
                            $reviewPage = 1

                            while ($true) {
                                $reviewView = Show-PwWorkshopPagedTable `
                                    -Title 'Ownership Review' `
                                    -Rows $numberedReviewItems `
                                    -Properties @(
                                        '#',
                                        'OwnerName',
                                        'SourceArea',
                                        'PackageType',
                                        'RelativePath'
                                    ) `
                                    -Page $reviewPage
                                $ownershipChoice = Read-Host (
                                    'Enter # to assign, [N] Next, [P] Previous, ' +
                                        '[B] Back, or Q to quit'
                                )

                                if ($ownershipChoice -match '^(?i:N)$') {
                                    $reviewPage = [math]::Min(
                                        $reviewView.Page + 1,
                                        $reviewView.PageCount
                                    )
                                    continue
                                }

                                if ($ownershipChoice -match '^(?i:P)$') {
                                    $reviewPage = [math]::Max(
                                        1,
                                        $reviewView.Page - 1
                                    )
                                    continue
                                }

                                break
                            }

                            if (
                                Test-PwWorkshopQuitSelection $ownershipChoice
                            ) {
                                $quitRequested = $true
                                break
                            }

                            if (
                                -not (
                                    Test-PwWorkshopBackSelection $ownershipChoice
                                ) -and
                                $ownershipChoice -match '^\d+$'
                            ) {
                                $reviewIndex = [int]$ownershipChoice - 1

                                if (
                                    $reviewIndex -ge 0 -and
                                    $reviewIndex -lt $reviewItems.Count
                                ) {
                                    $reviewItem = $reviewItems[$reviewIndex]
                                    $persistentCatalog = Get-PwPersistentModCatalog
                                    $catalogEntries = @($persistentCatalog.Mods)
                                    $numberedCatalogEntries = @(
                                        $catalogEntries |
                                            Select-Object `
                                            @{Name = '#'; Expression = {
                                                1 + $catalogEntries.IndexOf($_)
                                            }},
                                            CatalogKey,
                                            DisplayName,
                                            ComponentNames
                                    )
                                    $catalogPage = 1

                                    while ($true) {
                                        $catalogView = Show-PwWorkshopPagedTable `
                                            -Title (
                                                "Assign '$($reviewItem.OwnerName)'"
                                            ) `
                                            -Rows $numberedCatalogEntries `
                                            -Properties @(
                                                '#',
                                                'CatalogKey',
                                                'DisplayName',
                                                'ComponentNames'
                                            ) `
                                            -Page $catalogPage
                                        $ownerChoice = Read-Host (
                                            'Catalog #, [N] Next, [P] Previous, ' +
                                                '[C] Create identity, [B] Back, or Q'
                                        )

                                        if ($ownerChoice -match '^(?i:P)$') {
                                            $catalogPage = [math]::Max(
                                                1,
                                                $catalogView.Page - 1
                                            )
                                            continue
                                        }

                                        if (
                                            $ownerChoice -match '^(?i:N)$'
                                        ) {
                                            $catalogPage = [math]::Min(
                                                $catalogView.Page + 1,
                                                $catalogView.PageCount
                                            )
                                            continue
                                        }

                                        break
                                    }

                                    if (
                                        Test-PwWorkshopQuitSelection $ownerChoice
                                    ) {
                                        $quitRequested = $true
                                        break
                                    }

                                    if ($ownerChoice -match '^(?i:C)$') {
                                        $newName = Read-Host (
                                            'New catalog display name ' +
                                                '(Enter uses component name, [B] Back)'
                                        )

                                        if (
                                            -not (
                                                Test-PwWorkshopBackSelection $newName
                                            )
                                        ) {
                                            if (
                                                [string]::IsNullOrWhiteSpace($newName)
                                            ) {
                                                $newName = $reviewItem.OwnerName
                                            }
                                            New-PwModCatalogRecord `
                                                -DisplayName $newName `
                                                -ComponentName $reviewItem.OwnerName `
                                                -Confirm:$false |
                                                Select-Object `
                                                    CatalogKey,
                                                    DisplayName,
                                                    ComponentNames,
                                                    ReconciliationStatus |
                                                Format-List
                                        }
                                    }
                                    elseif (
                                        -not (
                                            Test-PwWorkshopBackSelection $ownerChoice
                                        ) -and
                                        $ownerChoice -match '^\d+$'
                                    ) {
                                        $ownerIndex = [int]$ownerChoice - 1

                                        if (
                                            $ownerIndex -ge 0 -and
                                            $ownerIndex -lt $catalogEntries.Count
                                        ) {
                                            $ownerRecord = $catalogEntries[$ownerIndex]
                                            $confirmOwner = Read-Host (
                                                "[A] Assign '$($reviewItem.OwnerName)' " +
                                                    "to '$($ownerRecord.DisplayName)', " +
                                                    '[B] Back, or Q to quit'
                                            )

                                            if (
                                                Test-PwWorkshopQuitSelection `
                                                    $confirmOwner
                                            ) {
                                                $quitRequested = $true
                                                break
                                            }

                                            if ($confirmOwner -match '^(?i:A)$') {
                                                Set-PwModCatalogMetadata `
                                                    -CatalogKey $ownerRecord.CatalogKey `
                                                    -ComponentName $reviewItem.OwnerName `
                                                    -Confirm:$false |
                                                    Select-Object `
                                                        CatalogKey,
                                                        DisplayName,
                                                        ComponentNames,
                                                        ReconciliationStatus |
                                                    Format-List
                                            }
                                        }
                                        else {
                                            Write-Host (
                                                'Catalog number was not found.'
                                            ) -ForegroundColor Yellow
                                        }
                                    }
                                }
                                else {
                                    Write-Host (
                                        'Ownership item number was not found.'
                                    ) -ForegroundColor Yellow
                                }
                            }
                        }
                        else {
                            Clear-Host
                            Write-Host 'Ownership Review' -ForegroundColor Cyan
                            Write-Host ''
                            Write-Host (
                                'All staged components already have reviewed ' +
                                    'catalog ownership.'
                            ) -ForegroundColor Green
                            $ownershipDone = Read-Host (
                                '[B] Back, Enter to return, or Q to quit'
                            )

                            if (
                                Test-PwWorkshopQuitSelection $ownershipDone
                            ) {
                                $quitRequested = $true
                                break
                            }
                        }

                        continue
                    }

                    if ($catalogChoice -match '^(?i:H)$') {
                        $compatibility = Get-PwCompatibilityReport
                        $compatibilityChoice = Read-PwWorkshopPagedTable `
                            -Title (
                                'Compatibility and Conflict Report | ' +
                                "$($compatibility.ConflictCount) conflicts, " +
                                "$($compatibility.ReviewCount) reviews"
                            ) `
                            -Rows @(
                                Get-PwCompatibilityDisplayRows `
                                    -Compatibility $compatibility
                            ) `
                            -Properties @('Category', 'Name', 'Details') `
                            -Prompt '[B] Back, Enter to return, or Q to quit'
                        if (
                            Test-PwWorkshopQuitSelection $compatibilityChoice
                        ) {
                            $quitRequested = $true
                            break
                        }
                        continue
                    }
                }
            }
            '2' {
                $skipReturnPrompt = $true
                $archiveMenuActive = $true

                while ($archiveMenuActive) {
                    $archives = @(
                        Invoke-PwWorkshopMenuAction -Action Archives
                    )
                    $archiveChoice = Read-PwWorkshopPagedTable `
                        -Title 'Archive Inventory' `
                        -Rows $archives `
                        -Properties @(
                            'Name',
                            'NexusModId',
                            'ArchiveVersion',
                            'DownloadedAt',
                            'InstallNames'
                        ) `
                        -Prompt (
                            '[I] Inspect and import, [B] Back, or Q to quit'
                        )

                    if (Test-PwWorkshopQuitSelection $archiveChoice) {
                        $quitRequested = $true
                        break
                    }

                    if (
                        [string]::IsNullOrWhiteSpace($archiveChoice) -or
                        (Test-PwWorkshopBackSelection $archiveChoice)
                    ) {
                        $archiveMenuActive = $false
                        break
                    }

                    if ($archiveChoice -match '^(?i:I)$') {
                        try {
                            $archivePath = Read-Host (
                                'Archive path or filename from 01_Archives, or Q'
                            )

                            if (Test-PwWorkshopQuitSelection $archivePath) {
                                $quitRequested = $true
                                break
                            }

                            if (Test-PwWorkshopBackSelection $archivePath) {
                                continue
                            }

                            if (
                                -not [string]::IsNullOrWhiteSpace($archivePath)
                            ) {
                                if (
                                    -not [System.IO.Path]::IsPathRooted(
                                        $archivePath
                                    )
                                ) {
                                    $archivePath = Join-Path `
                                        (Get-PwPaths).Archives `
                                        $archivePath
                                }

                                $inspection = Get-PwModArchiveInfo `
                                    -Path $archivePath
                                if (-not $inspection.IsSafe) {
                                    throw (
                                        'Archive failed safety inspection: ' +
                                            ($inspection.Errors -join ' ')
                                    )
                                }

                                $inspectionChoice = `
                                    Read-PwWorkshopPagedTable `
                                        -Title (
                                            'Archive Inspection | ' +
                                            "$($inspection.Format), " +
                                            "$($inspection.FileCount) files, " +
                                            "$($inspection.TotalUncompressedBytes) bytes"
                                        ) `
                                        -Rows @(
                                            $inspection.Entries |
                                                Where-Object {
                                                    -not $_.IsDirectory
                                                }
                                        ) `
                                        -Properties @(
                                            'ArchivePath',
                                            'Category',
                                            'DeploymentRelativePath',
                                            'ReviewRequired'
                                        ) `
                                        -Prompt (
                                            '[C] Continue import, [B] Back, ' +
                                                'or Q to quit'
                                        )
                                if (
                                    Test-PwWorkshopQuitSelection `
                                        $inspectionChoice
                                ) {
                                    $quitRequested = $true
                                    break
                                }
                                if (
                                    (Test-PwWorkshopBackSelection `
                                        $inspectionChoice) -or
                                    $inspectionChoice -notmatch '^(?i:C)$'
                                ) {
                                    continue
                                }

                                $name = Read-Host (
                                    'Package name (or Q to quit, B to back)'
                                )

                                if (Test-PwWorkshopQuitSelection $name) {
                                    $quitRequested = $true
                                    break
                                }

                                if (Test-PwWorkshopBackSelection $name) {
                                    continue
                                }

                                if (-not [string]::IsNullOrWhiteSpace($name)) {
                                    $version = Read-Host (
                                        'Package version (or Q to quit, B to back)'
                                    )

                                    if (Test-PwWorkshopQuitSelection $version) {
                                        $quitRequested = $true
                                        break
                                    }

                                    if (Test-PwWorkshopBackSelection $version) {
                                        continue
                                    }

                                    if (
                                        -not [string]::IsNullOrWhiteSpace($version)
                                    ) {
                                        $confirmImport = Read-Host (
                                            '[A] Import into normalized staging, ' +
                                                '[B] Back, or Q to quit'
                                        )

                                        if (
                                            Test-PwWorkshopQuitSelection `
                                                $confirmImport
                                        ) {
                                            $quitRequested = $true
                                            break
                                        }

                                        if (
                                            Test-PwWorkshopBackSelection `
                                                $confirmImport
                                        ) {
                                            continue
                                        }

                                        if (
                                            $confirmImport -match '^(?i:A)$'
                                        ) {
                                            Import-PwModArchive `
                                                -Path $archivePath `
                                                -Name $name `
                                                -Version $version `
                                                -Confirm:$false |
                                                Format-List
                                        }
                                    }
                                }
                            }
                        }
                        catch {
                            Write-Host $_.Exception.Message `
                                -ForegroundColor Red
                        }
                    }
                }
            }
            '3' {
                $skipReturnPrompt = $true
                $stagingMenuActive = $true

                while ($stagingMenuActive) {
                    $stagingRows = @(
                        Invoke-PwWorkshopMenuAction -Action Staging
                    )
                    $stagingChoice = Read-PwWorkshopPagedTable `
                        -Title 'Loose Staging and Ownership Snapshot' `
                        -Rows $stagingRows `
                        -Properties @(
                            'Name',
                            'Enabled',
                            'EnabledSource',
                            'Types',
                            'FileCount'
                        ) `
                        -Prompt '[B] Back, Enter to return, or Q to quit'

                    if (Test-PwWorkshopQuitSelection $stagingChoice) {
                        $quitRequested = $true
                        break
                    }

                    if (
                        [string]::IsNullOrWhiteSpace($stagingChoice) -or
                        (Test-PwWorkshopBackSelection $stagingChoice)
                    ) {
                        $stagingMenuActive = $false
                        break
                    }
                }
            }
            '4' {
                $skipReturnPrompt = $true
                $updatesMenuActive = $true

                while ($updatesMenuActive) {
                    try {
                        $updates = @(
                            Invoke-PwWorkshopMenuAction -Action Updates
                        )
                        $sourceUpdates = @(
                            Invoke-PwWorkshopMenuAction -Action SourceUpdates
                        )
                        $updateRows = @(
                            $updates | ForEach-Object {
                                [PSCustomObject]@{
                                    Kind = 'Mod'
                                    Name = $_.Name
                                    Id = $_.NexusModId
                                    Local = $_.LocalVersion
                                    Remote = $_.RemoteVersion
                                    Status = $_.Status
                                }
                            }
                            $sourceUpdates | ForEach-Object {
                                [PSCustomObject]@{
                                    Kind = 'Tool'
                                    Name = $_.Name
                                    Id = $_.Provider
                                    Local = $_.LocalVersion
                                    Remote = $_.RemoteVersion
                                    Status = $_.Status
                                }
                            }
                        )
                        $selectedId = Read-PwWorkshopPagedTable `
                            -Title 'Mod and Tool Updates' `
                            -Rows $updateRows `
                            -Properties @(
                                'Kind',
                                'Name',
                                'Id',
                                'Local',
                                'Remote',
                                'Status'
                            ) `
                            -Prompt (
                                'Nexus mod ID, [U] record UE4SS baseline, ' +
                                    'Enter to return, or Q to quit'
                            )

                        if (Test-PwWorkshopQuitSelection $selectedId) {
                            $quitRequested = $true
                            break
                        }

                        if ([string]::IsNullOrWhiteSpace($selectedId)) {
                            $updatesMenuActive = $false
                            break
                        }

                        if ($selectedId -match '^(?i:U)$') {
                            $ue4ss = $sourceUpdates |
                                Where-Object Key -eq 'UE4SS' |
                                Select-Object -First 1

                            if (-not $ue4ss) {
                                Write-Host 'UE4SS source is not configured.' `
                                    -ForegroundColor Yellow
                            }
                            else {
                                $ue4ss |
                                    Select-Object `
                                        Name,
                                        RemoteFileName,
                                        RemoteUpdatedAt,
                                        Status,
                                        DownloadUrl |
                                    Format-List
                                    $baseline = Read-Host (
                                        '[A] Confirm this exact build is installed and ' +
                                            'validated, [B] Back, or Q to quit'
                                    )

                                if (Test-PwWorkshopQuitSelection $baseline) {
                                    $quitRequested = $true
                                    break
                                }

                                if (Test-PwWorkshopBackSelection $baseline) {
                                    continue
                                }

                                if ($baseline -match '^(?i:A)$') {
                                    Set-PwGitHubSourceBaseline `
                                        -Key UE4SS `
                                        -Confirm:$false |
                                        Select-Object `
                                            Name,
                                            RemoteFileName,
                                            RemoteUpdatedAt |
                                        Format-List
                                }
                            }
                        }
                        elseif ($selectedId -match '^\d+$') {
                            $selected = $updates |
                                Where-Object NexusModId -eq ([int]$selectedId) |
                                Select-Object -First 1

                            if (-not $selected) {
                                Write-Host 'Mod ID is not in this report.' `
                                    -ForegroundColor Yellow
                            }
                            else {
                                $mode = Read-Host (
                                    '[M]anual, [D]irect Premium, [B] Back, or Q to quit'
                                )

                                if (Test-PwWorkshopQuitSelection $mode) {
                                    $quitRequested = $true
                                    break
                                }

                                if (Test-PwWorkshopBackSelection $mode) {
                                    continue
                                }

                                if ($mode -match '^[Mm]') {
                                    Open-PwNexusModPage `
                                        -ModId $selected.NexusModId `
                                        -Launch |
                                        Out-Null
                                }
                                elseif ($mode -match '^[Dd]') {
                                    Save-PwNexusModUpdate `
                                        -ModId $selected.NexusModId `
                                        -FileId $selected.RemoteFileId
                                }
                            }
                        }
                    }
                    catch {
                        Write-Host $_.Exception.Message -ForegroundColor Red
                    }
                }
            }
            '8' {
                $skipReturnPrompt = $true
                $diagnosticsMenuActive = $true

                while ($diagnosticsMenuActive) {
                    Invoke-PwWorkshopMenuAction -Action Diagnostics |
                        Format-List
                    $diagnosticsChoice = Read-Host (
                        '[B] Back, or Enter to return to the menu'
                    )

                    if (Test-PwWorkshopQuitSelection $diagnosticsChoice) {
                        $quitRequested = $true
                        break
                    }

                    if (
                        [string]::IsNullOrWhiteSpace($diagnosticsChoice) -or
                        (Test-PwWorkshopBackSelection $diagnosticsChoice)
                    ) {
                        $diagnosticsMenuActive = $false
                        break
                    }
                }
            }
            '9' {
                $skipReturnPrompt = $true
                $inventoryMenuActive = $true

                while ($inventoryMenuActive) {
                    $inventoryRows = @(
                        Invoke-PwWorkshopMenuAction -Action Inventory
                    )
                    $inventoryChoice = Read-PwWorkshopPagedTable `
                        -Title 'Deployment Inventory' `
                        -Rows $inventoryRows `
                        -Properties @(
                            'Name',
                            'Version',
                            'Profile',
                            'Status',
                            'FileCount'
                        ) `
                        -Prompt '[B] Back, Enter to return, or Q to quit'

                    if (Test-PwWorkshopQuitSelection $inventoryChoice) {
                        $quitRequested = $true
                        break
                    }

                    if (
                        [string]::IsNullOrWhiteSpace($inventoryChoice) -or
                        (Test-PwWorkshopBackSelection $inventoryChoice)
                    ) {
                        $inventoryMenuActive = $false
                        break
                    }
                }
            }
            '0' {
                $skipReturnPrompt = $true
                $historyMenuActive = $true

                while ($historyMenuActive) {
                    $historyRows = @(
                        Invoke-PwWorkshopMenuAction -Action History
                    )
                    $historyChoice = Read-PwWorkshopPagedTable `
                        -Title 'Deployment History' `
                        -Rows $historyRows `
                        -Properties @(
                            'Timestamp',
                            'Type',
                            'Profile',
                            'Status',
                            'FileCount'
                        ) `
                        -Prompt '[B] Back, Enter to return, or Q to quit'

                    if (Test-PwWorkshopQuitSelection $historyChoice) {
                        $quitRequested = $true
                        break
                    }

                    if (
                        [string]::IsNullOrWhiteSpace($historyChoice) -or
                        (Test-PwWorkshopBackSelection $historyChoice)
                    ) {
                        $historyMenuActive = $false
                        break
                    }
                }
            }
            '6' {
                $skipReturnPrompt = $true
                $modSetsMenuActive = $true

                while ($modSetsMenuActive) {
                    $profileName = (Get-PwWorkshopConfig).Deployment.ActiveProfile
                    $modSets = @(Get-PwProfileModSets -Name $profileName)

                    Write-Host "Profile mod sets for: $profileName" -ForegroundColor Cyan
                    if ($modSets.Count -eq 0) {
                        Write-Host 'No mod sets have been defined yet.'
                        $modSetChoice = Read-Host (
                            '[N] New set, [B] Back, or Q to quit'
                        )
                    }
                    else {
                        $modSetRows = @(
                            $modSets |
                            Select-Object `
                                @{Name = '#'; Expression = {
                                    1 + $modSets.IndexOf($_)
                                }},
                                Name,
                                Description,
                                IsActive,
                                @{Name = 'CatalogKeys'; Expression = {
                                    @($_.CatalogKeys) -join ', '
                                }}
                        )
                        $modSetChoice = Read-PwWorkshopPagedTable `
                            -Title "Profile Mod Sets: $profileName" `
                            -Rows $modSetRows `
                            -Properties @(
                                '#',
                                'Name',
                                'Description',
                                'IsActive',
                                'CatalogKeys'
                            ) `
                            -Prompt (
                                '[1-#] Edit, [N] New, [V] Preview active, ' +
                                    '[B] Back, or Q to quit'
                            )
                    }

                    if (Test-PwWorkshopQuitSelection $modSetChoice) {
                        $quitRequested = $true
                        break
                    }

                    if (
                        [string]::IsNullOrWhiteSpace($modSetChoice) -or
                        (Test-PwWorkshopBackSelection $modSetChoice)
                    ) {
                        $modSetsMenuActive = $false
                        break
                    }

                    if ($modSetChoice -match '^(?i:N)$') {
                        $setName = Read-Host 'Set name (or B to back)'
                        if (Test-PwWorkshopQuitSelection $setName) {
                            $quitRequested = $true
                            break
                        }

                        if (Test-PwWorkshopBackSelection $setName) {
                            continue
                        }

                        $catalogKeysInput = Read-Host (
                            'Catalog keys, comma-separated (or B to back)'
                        )
                        if (Test-PwWorkshopQuitSelection $catalogKeysInput) {
                            $quitRequested = $true
                            break
                        }

                        if (Test-PwWorkshopBackSelection $catalogKeysInput) {
                            continue
                        }

                        $description = Read-Host (
                            'Description (optional, or B to back)'
                        )
                        if (Test-PwWorkshopQuitSelection $description) {
                            $quitRequested = $true
                            break
                        }

                        if (Test-PwWorkshopBackSelection $description) {
                            continue
                        }

                        $activate = Read-Host (
                            '[A] Save and activate this mod set, [S] Save only, [B] Back, or Q to quit'
                        )

                        if (Test-PwWorkshopQuitSelection $activate) {
                            $quitRequested = $true
                            break
                        }

                        if (Test-PwWorkshopBackSelection $activate) {
                            continue
                        }

                        if ($activate -match '^(?i:[AS])$') {
                            $selectedKeys = @(
                                $catalogKeysInput -split ',' |
                                    ForEach-Object { $_.Trim() } |
                                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                            )
                            Set-PwProfileModSet `
                                -Name $profileName `
                                -SetName $setName `
                                -Description $description `
                                -CatalogKeys $selectedKeys `
                                -Activate:($activate -match '^(?i:A)$') |
                            Select-Object Name, Description, IsActive, CatalogKeys |
                                Format-List
                        }
                    }
                    elseif ($modSetChoice -match '^\d+$') {
                        $modSetIndex = [int]$modSetChoice - 1

                        if (
                            $modSetIndex -lt 0 -or
                            $modSetIndex -ge $modSets.Count
                        ) {
                            Write-Host 'Invalid set number.' -ForegroundColor Yellow
                            continue
                        }

                        $selectedSet = $modSets[$modSetIndex]
                        $editedName = Read-Host (
                            "Set name [$($selectedSet.Name)] (or B to back)"
                        )

                        if (Test-PwWorkshopQuitSelection $editedName) {
                            $quitRequested = $true
                            break
                        }

                        if (Test-PwWorkshopBackSelection $editedName) {
                            continue
                        }

                        if ([string]::IsNullOrWhiteSpace($editedName)) {
                            $editedName = $selectedSet.Name
                        }

                        $editedDescription = Read-Host (
                            "Description [$($selectedSet.Description)] (or B to back)"
                        )

                        if (Test-PwWorkshopQuitSelection $editedDescription) {
                            $quitRequested = $true
                            break
                        }

                        if (Test-PwWorkshopBackSelection $editedDescription) {
                            continue
                        }

                        if ([string]::IsNullOrWhiteSpace($editedDescription)) {
                            $editedDescription = $selectedSet.Description
                        }

                        $editedCatalogKeys = Read-Host (
                            "Catalog keys, comma-separated " +
                                "[{0}] (or B to back)" -f (
                                    @($selectedSet.CatalogKeys) -join ', '
                                )
                        )

                        if (Test-PwWorkshopQuitSelection $editedCatalogKeys) {
                            $quitRequested = $true
                            break
                        }

                        if (Test-PwWorkshopBackSelection $editedCatalogKeys) {
                            continue
                        }

                        if ([string]::IsNullOrWhiteSpace($editedCatalogKeys)) {
                            $editedCatalogKeys = @($selectedSet.CatalogKeys) -join ', '
                        }

                        $editedActivate = Read-Host (
                            '[A] Save and activate this mod set, [S] Save only, [B] Back, or Q to quit'
                        )

                        if (Test-PwWorkshopQuitSelection $editedActivate) {
                            $quitRequested = $true
                            break
                        }

                        if (Test-PwWorkshopBackSelection $editedActivate) {
                            continue
                        }

                        if ($editedActivate -match '^(?i:[AS])$') {
                            $editedKeys = @(
                                $editedCatalogKeys -split ',' |
                                    ForEach-Object { $_.Trim() } |
                                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                            )

                            Set-PwProfileModSet `
                                -Name $profileName `
                                -SetName $editedName `
                                -Description $editedDescription `
                                -CatalogKeys $editedKeys `
                                -Activate:($editedActivate -match '^(?i:A)$') |
                                Select-Object Name, Description, IsActive, CatalogKeys |
                                Format-List
                        }
                    }
                    elseif ($modSetChoice -match '^(?i:V)$') {
                        $preview = Get-PwProfileModSetPreview -Name $profileName
                        $previewChoice = Read-PwWorkshopPagedTable `
                            -Title (
                                "Active Set Preview: $($preview.Profile) / " +
                                    "$($preview.ModSet) ($($preview.ModCount) mods)"
                            ) `
                            -Rows @($preview.Mods) `
                            -Properties @(
                                'CatalogKey',
                                'DisplayName',
                                'InstalledVersion',
                                'ReconciliationStatus',
                                'Types'
                            ) `
                            -Prompt '[B] Back, Enter to return, or Q to quit'

                        if (Test-PwWorkshopQuitSelection $previewChoice) {
                            $quitRequested = $true
                            break
                        }
                    }
                }
            }
            '7' {
                $skipReturnPrompt = $true
                $assemblyMenuActive = $true

                while ($assemblyMenuActive) {
                    try {
                        $assemblyPlan = Get-PwProfileAssemblyPlan
                        $assemblyChoice = Read-PwWorkshopPagedTable `
                            -Title (
                                "Deployment Assembly Review: " +
                                "$($assemblyPlan.Profile) / " +
                                "$($assemblyPlan.ModSet) | " +
                                "$($assemblyPlan.PackageCount) packages, " +
                                "$($assemblyPlan.FileCount) files"
                            ) `
                            -Rows @($assemblyPlan.Packages) `
                            -Properties @(
                                'CatalogKey',
                                'Version',
                                'PackageTypes',
                                'FileCount',
                                'Action'
                            ) `
                            -Prompt (
                                '[S] Standard staged build, ' +
                                    '[E] Experiment/debug build, ' +
                                    '[C] Adopt current-game-only mod, ' +
                                    '[D] Verify and deploy, ' +
                                    '[V] Verify assembled output, ' +
                                    '[R] Compare with current game, ' +
                                    '[B] Back, or Q to quit'
                            )

                        if (Test-PwWorkshopQuitSelection $assemblyChoice) {
                            $quitRequested = $true
                            break
                        }
                        if (
                            [string]::IsNullOrWhiteSpace($assemblyChoice) -or
                            (Test-PwWorkshopBackSelection $assemblyChoice)
                        ) {
                            $assemblyMenuActive = $false
                            break
                        }

                        if ($assemblyChoice -match '^(?i:S)$') {
                            $build = Build-PwProfileDeployment `
                                -Apply `
                                -Confirm:$false
                            $build |
                                Select-Object `
                                    Profile,
                                    ModSet,
                                    Status,
                                    PackageCount,
                                    FileCount,
                                    DeployedToGame,
                                    ManifestPath |
                                Format-List
                            Write-Host (
                                'Workshop output was built and verified. ' +
                                'No live game files were changed.'
                            ) -ForegroundColor Green
                            Read-Host 'Press Enter to review the refreshed plan' |
                                Out-Null
                            continue
                        }

                        if ($assemblyChoice -match '^(?i:E)$') {
                            $experimentLabel = Read-Host (
                                'Experiment label [Debug], [B] Back, or Q to quit'
                            )
                            if (
                                Test-PwWorkshopQuitSelection $experimentLabel
                            ) {
                                $quitRequested = $true
                                break
                            }
                            if (
                                Test-PwWorkshopBackSelection $experimentLabel
                            ) {
                                continue
                            }
                            if (
                                [string]::IsNullOrWhiteSpace($experimentLabel)
                            ) {
                                $experimentLabel = 'Debug'
                            }
                            $experiment = Build-PwProfileExperiment `
                                -Label $experimentLabel `
                                -Apply `
                                -Confirm:$false
                            $experiment |
                                Select-Object `
                                    Profile,
                                    Label,
                                    Status,
                                    FileCount,
                                    DeployedToGame,
                                    ExperimentRoot,
                                    ManifestPath |
                                Format-List
                            Write-Host (
                                'Isolated experiment output is ready. ' +
                                'No curated package or live game file changed.'
                            ) -ForegroundColor Green
                            Read-Host 'Press Enter to return to workflows' |
                                Out-Null
                            continue
                        }

                        if ($assemblyChoice -match '^(?i:C)$') {
                            $candidates = @(Get-PwCurrentGameOnlyMods)
                            $candidateRows = @(
                                for (
                                    $candidateIndex = 0
                                    $candidateIndex -lt $candidates.Count
                                    $candidateIndex++
                                ) {
                                    [PSCustomObject]@{
                                        '#' = $candidateIndex + 1
                                        CandidateName = (
                                            $candidates[$candidateIndex].
                                                CandidateName
                                        )
                                        FileCount = (
                                            $candidates[$candidateIndex].
                                                FileCount
                                        )
                                    }
                                }
                            )
                            $candidateChoice = Read-PwWorkshopPagedTable `
                                -Title 'Adopt Current-Game-Only Mod' `
                                -Rows $candidateRows `
                                -Properties @(
                                    '#',
                                    'CandidateName',
                                    'FileCount'
                                ) `
                                -Prompt (
                                    'Candidate #, [B] Back, or Q to quit'
                                )
                            if (
                                Test-PwWorkshopQuitSelection $candidateChoice
                            ) {
                                $quitRequested = $true
                                break
                            }
                            if (
                                Test-PwWorkshopBackSelection $candidateChoice
                            ) {
                                continue
                            }
                            if ($candidateChoice -notmatch '^\d+$') {
                                continue
                            }
                            $candidateIndex = [int]$candidateChoice - 1
                            if (
                                $candidateIndex -lt 0 -or
                                $candidateIndex -ge $candidates.Count
                            ) {
                                Write-Host (
                                    'Candidate number was not found.'
                                ) -ForegroundColor Yellow
                                continue
                            }

                            $candidate = $candidates[$candidateIndex]
                            $nexusId = Read-Host (
                                'Verified Nexus mod ID, Enter for manual ' +
                                'catalog identity, [B] Back, or Q to quit'
                            )
                            if (Test-PwWorkshopQuitSelection $nexusId) {
                                $quitRequested = $true
                                break
                            }
                            if (Test-PwWorkshopBackSelection $nexusId) {
                                continue
                            }
                            $adoptionParameters = @{
                                CandidateName = $candidate.CandidateName
                            }
                            if ($nexusId -match '^\d+$') {
                                $adoptionParameters.NexusModId = [int]$nexusId
                            }
                            elseif (
                                -not [string]::IsNullOrWhiteSpace($nexusId)
                            ) {
                                Write-Host (
                                    'Nexus mod ID must be numeric.'
                                ) -ForegroundColor Yellow
                                continue
                            }

                            $adoptionPlan = `
                                Get-PwCurrentGameModAdoptionPlan `
                                    @adoptionParameters
                            $adoptionPlan |
                                Select-Object `
                                    CandidateName,
                                    CatalogKey,
                                    CatalogExists,
                                    NexusModId,
                                    FileCount,
                                    CanAdopt |
                                Format-List
                            if ($adoptionPlan.NexusIdentity) {
                                $adoptionPlan.NexusIdentity |
                                    Select-Object `
                                        NexusModId,
                                        Name,
                                        Version,
                                        NameMatch,
                                        NexusUrl |
                                    Format-List
                            }

                            $approveAdoption = Read-Host (
                                '[A] Adopt into staging and catalog, ' +
                                '[B] Back, or Q to quit'
                            )
                            if (
                                Test-PwWorkshopQuitSelection $approveAdoption
                            ) {
                                $quitRequested = $true
                                break
                            }
                            if (
                                Test-PwWorkshopBackSelection $approveAdoption
                            ) {
                                continue
                            }
                            if ($approveAdoption -notmatch '^(?i:A)$') {
                                continue
                            }

                            $adoptionResult = Import-PwCurrentGameMod `
                                @adoptionParameters `
                                -ApproveIdentity `
                                -Apply `
                                -Confirm:$false
                            $adoptionResult | Format-List

                            if ($adoptionResult.NexusModId -gt 0) {
                                $remoteFiles = @(
                                    Get-PwNexusModFiles `
                                        -ModId $adoptionResult.NexusModId
                                )
                                $remoteRows = @(
                                    for (
                                        $fileIndex = 0
                                        $fileIndex -lt $remoteFiles.Count
                                        $fileIndex++
                                    ) {
                                        [PSCustomObject]@{
                                            '#' = $fileIndex + 1
                                            FileId = $remoteFiles[
                                                $fileIndex
                                            ].FileId
                                            Name = $remoteFiles[
                                                $fileIndex
                                            ].Name
                                            Version = $remoteFiles[
                                                $fileIndex
                                            ].Version
                                            Category = $remoteFiles[
                                                $fileIndex
                                            ].Category
                                        }
                                    }
                                )
                                $remoteChoice = Read-PwWorkshopPagedTable `
                                    -Title (
                                        'Nexus Files for ' +
                                        $adoptionResult.NexusModId
                                    ) `
                                    -Rows $remoteRows `
                                    -Properties @(
                                        '#',
                                        'FileId',
                                        'Name',
                                        'Version',
                                        'Category'
                                    ) `
                                    -Prompt (
                                        'File # to download, [O] Open Nexus, ' +
                                        '[B] Back, or Q to quit'
                                    )
                                if (
                                    Test-PwWorkshopQuitSelection $remoteChoice
                                ) {
                                    $quitRequested = $true
                                    break
                                }
                                if ($remoteChoice -match '^(?i:O)$') {
                                    Open-PwNexusModPage `
                                        -ModId $adoptionResult.NexusModId `
                                        -Launch |
                                        Out-Null
                                }
                                elseif ($remoteChoice -match '^\d+$') {
                                    $fileIndex = [int]$remoteChoice - 1
                                    if (
                                        $fileIndex -ge 0 -and
                                        $fileIndex -lt $remoteFiles.Count
                                    ) {
                                        Save-PwNexusModUpdate `
                                            -ModId (
                                                $adoptionResult.NexusModId
                                            ) `
                                            -FileId (
                                                $remoteFiles[$fileIndex].FileId
                                            ) |
                                            Format-List
                                    }
                                }
                            }
                            continue
                        }

                        if ($assemblyChoice -match '^(?i:D)$') {
                            $readiness = Test-PwDeploymentReadiness
                            $readiness |
                                Select-Object `
                                    ReadyToDeploy,
                                    DeploymentFileCount,
                                    IdenticalCount,
                                    CreateCount,
                                    UpdateCount,
                                    CurrentGameOnlyCount,
                                    RuntimeStateOnlyCount,
                                    RequirementNoticeCount,
                                    WarningCount |
                                Format-List

                            if ($readiness.RequirementNoticeCount -gt 0) {
                                Write-Host (
                                    'Package requirements and expected ' +
                                    'destinations:'
                                ) -ForegroundColor Yellow
                                $readiness.RequirementNotices |
                                    Select-Object `
                                        CatalogKey,
                                        Requirement,
                                        PayloadNames,
                                        ExpectedDestination,
                                        RequirementPresent,
                                        DestinationVerified,
                                        Severity |
                                    Format-Table -AutoSize -Wrap
                            }

                            if ($readiness.WarningCount -gt 0) {
                                Write-Host (
                                    'Manual review warnings:'
                                ) -ForegroundColor Yellow
                                $readiness.Warnings |
                                    ForEach-Object {
                                        Write-Host " - $_" `
                                            -ForegroundColor Yellow
                                    }
                            }

                            if (-not $readiness.ReadyToDeploy) {
                                throw (
                                    'Direct deployment is blocked by failed ' +
                                    'verification.'
                                )
                            }

                            Write-Host (
                                'This will back up overwritten files and copy ' +
                                'verified changes into the live Palworld game.'
                            ) -ForegroundColor Yellow
                            $deployConfirmation = Read-Host (
                                'Type DEPLOY to continue, [B] Back, or Q to quit'
                            )
                            if (
                                Test-PwWorkshopQuitSelection `
                                    $deployConfirmation
                            ) {
                                $quitRequested = $true
                                break
                            }
                            if (
                                Test-PwWorkshopBackSelection `
                                    $deployConfirmation
                            ) {
                                continue
                            }
                            if ($deployConfirmation -cne 'DEPLOY') {
                                Write-Host (
                                    'Deployment cancelled; confirmation did ' +
                                    'not match DEPLOY.'
                                ) -ForegroundColor Yellow
                                continue
                            }

                            Invoke-PwDeployment `
                                -Apply `
                                -Confirm:$false |
                                Select-Object `
                                    Profile,
                                    Status,
                                    Applied,
                                    Reason,
                                    Backup,
                                    LogPath,
                                    Files |
                                Format-List
                            continue
                        }

                        if ($assemblyChoice -match '^(?i:V)$') {
                            $validation = Test-PwProfileDeploymentAssembly
                            $validationChoice = Read-PwWorkshopPagedTable `
                                -Title (
                                    "Assembly Verification | " +
                                    "$($validation.VerifiedCount) of " +
                                    "$($validation.FileCount) verified"
                                ) `
                                -Rows @($validation.Files) `
                                -Properties @(
                                    'CatalogKey',
                                    'RelativePath',
                                    'Status'
                                ) `
                                -Prompt (
                                    '[B] Back, Enter to return, or Q to quit'
                                )
                            if (
                                Test-PwWorkshopQuitSelection $validationChoice
                            ) {
                                $quitRequested = $true
                                break
                            }
                            continue
                        }

                        if ($assemblyChoice -match '^(?i:R)$') {
                            $readiness = Test-PwDeploymentReadiness
                            $comparisonRows = @(
                                $readiness.Comparison
                                $readiness.CurrentGameOnly
                            )
                            $readinessChoice = Read-PwWorkshopPagedTable `
                                -Title (
                                    "Current Game Comparison | " +
                                    "$($readiness.IdenticalCount) identical, " +
                                    "$($readiness.CreateCount) new, " +
                                    "$($readiness.UpdateCount) changed, " +
                                    "$($readiness.CurrentGameOnlyCount) " +
                                    'current-only mods, ' +
                                    "$($readiness.RuntimeStateOnlyCount) " +
                                    'runtime-only'
                                ) `
                                -Rows $comparisonRows `
                                -Properties @(
                                    'RelativePath',
                                    'Status',
                                    'Classification',
                                    'DeploymentHash',
                                    'GameHash'
                                ) `
                                -Prompt (
                                    '[B] Back, Enter to return, or Q to quit'
                                )
                            if (
                                Test-PwWorkshopQuitSelection $readinessChoice
                            ) {
                                $quitRequested = $true
                                break
                            }
                        }
                    }
                    catch {
                        Write-Host $_.Exception.Message -ForegroundColor Red
                        $assemblyErrorChoice = Read-Host (
                            '[B] Back, Enter to retry, or Q to quit'
                        )
                        if (
                            Test-PwWorkshopQuitSelection $assemblyErrorChoice
                        ) {
                            $quitRequested = $true
                            break
                        }
                        if (
                            Test-PwWorkshopBackSelection $assemblyErrorChoice
                        ) {
                            $assemblyMenuActive = $false
                            break
                        }
                    }
                }
            }
            '5' {
                $skipReturnPrompt = $true
                $compatibility = Get-PwCompatibilityReport
                $compatibilityChoice = Read-PwWorkshopPagedTable `
                    -Title (
                        'Compatibility and Conflict Report | ' +
                        "$($compatibility.ConflictCount) conflicts, " +
                        "$($compatibility.ReviewCount) reviews"
                    ) `
                    -Rows @(
                        Get-PwCompatibilityDisplayRows `
                            -Compatibility $compatibility
                    ) `
                    -Properties @('Category', 'Name', 'Details') `
                    -Prompt '[B] Back, Enter to return, or Q to quit'

                if (Test-PwWorkshopQuitSelection $compatibilityChoice) {
                    $running = $false
                    continue
                }
            }
            'Q' {
                $running = $false
                continue
            }
            default {
                Write-Host 'Invalid selection.' -ForegroundColor Yellow
            }
        }

        if ($quitRequested) {
            $running = $false
            continue
        }

        if ($running -and -not $skipReturnPrompt) {
            Write-Host ''
            $returnSelection = Read-Host (
                'Press Enter to return to the menu, or Q to quit'
            )

            if (Test-PwWorkshopQuitSelection $returnSelection) {
                $running = $false
            }
        }
    }
}

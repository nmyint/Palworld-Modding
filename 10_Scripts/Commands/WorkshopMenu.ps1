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
            -Text 'Sprint 4 - Catalog and Library Management' `
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
            -Text 'MOD CATALOG' `
            -Color Yellow `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [1] View catalog and version matches' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [2] View Nexus archive metadata' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [3] View loose staging snapshot' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [4] Check mod and tool updates' `
            -Width $Width
        New-PwWorkshopMenuLine -Width $Width
        New-PwWorkshopMenuLine `
            -Text 'WORKSHOP HEALTH' `
            -Color Yellow `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [5] Run diagnostics' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [6] View known-good installation inventory' `
            -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [7] View deployment and restore history' `
            -Width $Width
        New-PwWorkshopMenuLine -Width $Width
        New-PwWorkshopMenuLine `
            -Text '  [Q] Exit' `
            -Color Yellow `
            -Width $Width
        New-PwWorkshopMenuLine -Width $Width
        New-PwWorkshopMenuLine `
            -Text 'Press 1-7 or Q.' `
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
                -Text 'MOD CATALOG' `
                -Color Yellow `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text '  [1] Catalog and versions' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text '  [2] Nexus archive metadata' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text '  [3] Loose staging snapshot' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text '  [4] Check mod and tool updates' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text 'WORKSHOP HEALTH' `
                -Color Yellow `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text '  [5] Diagnostics' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text '  [6] Installation inventory' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text '  [7] Deployment history' `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text '  [Q] Exit' `
                -Color Yellow `
                -Width $Width
            New-PwWorkshopMenuLine `
                -Text 'Press 1-7 or Q.' `
                -Color DarkGray `
                -Width $Width
        )
    }
    $targetRenderedRows = $Height - 2
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

            if ($selection -in @('1', '2', '3', '4', '5', '6', '7', 'Q')) {
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

function Show-PwCatalogSummary {

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
    Write-Host ''
    $Catalog |
        Select-Object `
            ModCount,
            ArchiveCount,
            MatchedModCount,
            MissingArchiveCount,
            ArchiveOnlyCount,
            ModsJsonValid |
        Format-List

    if ($Catalog.Warnings.Count -gt 0) {
        Write-Host 'Warnings:' -ForegroundColor Yellow

        foreach ($warning in $Catalog.Warnings) {
            Write-Host " - $warning" -ForegroundColor Yellow
        }
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

function Invoke-PwWorkshopMenuAction {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'Summary',
            'Catalog',
            'CatalogPlan',
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
                $catalog = Invoke-PwWorkshopMenuAction -Action Catalog
                Show-PwCatalogSummary -Catalog $catalog
                $catalogChoice = Read-Host (
                    '[S] Preview persistent catalog sync, Enter to return, ' +
                        'or Q to quit'
                )

                if (Test-PwWorkshopQuitSelection $catalogChoice) {
                    $quitRequested = $true
                }
                elseif ($catalogChoice -match '^(?i:S)$') {
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
                        '[A] Apply this catalog sync, Enter to cancel, ' +
                            'or Q to quit'
                    )

                    if (Test-PwWorkshopQuitSelection $apply) {
                        $quitRequested = $true
                    }
                    elseif ($apply -match '^(?i:A)$') {
                        Update-PwModCatalog -Confirm:$false |
                            Select-Object `
                                Path,
                                HasChanges,
                                ProposedModCount,
                                NeedsMetadataCount |
                            Format-List
                    }
                }
            }
            '2' {
                Invoke-PwWorkshopMenuAction -Action Archives |
                    Format-Table `
                        Name,
                        NexusModId,
                        ArchiveVersion,
                        DownloadedAt,
                        InstallNames
            }
            '3' {
                Invoke-PwWorkshopMenuAction -Action Staging |
                    Format-Table Name, Enabled, EnabledSource, Types, FileCount
            }
            '4' {
                try {
                    $updates = @(
                        Invoke-PwWorkshopMenuAction -Action Updates
                    )
                    Show-PwUpdateReport -Updates $updates
                    Write-Host ''
                    Write-Host 'Configured tool and dependency sources:'
                    Invoke-PwWorkshopMenuAction -Action SourceUpdates |
                        Select-Object `
                            Name,
                            Provider,
                            LocalVersion,
                            RemoteVersion,
                            Status |
                        Format-Table -AutoSize
                    $selectedId = Read-Host (
                        'Enter a Nexus mod ID, Enter to return, or Q to quit'
                    )

                    if (Test-PwWorkshopQuitSelection $selectedId) {
                        $quitRequested = $true
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
                                '[M]anual, [D]irect Premium, or [Q]uit'
                            )

                            if (Test-PwWorkshopQuitSelection $mode) {
                                $quitRequested = $true
                            }
                            elseif ($mode -match '^[Mm]') {
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
            '5' {
                Invoke-PwWorkshopMenuAction -Action Diagnostics |
                    Format-List
            }
            '6' {
                Invoke-PwWorkshopMenuAction -Action Inventory |
                    Format-Table `
                        Name,
                        Version,
                        Profile,
                        Status,
                        FileCount
            }
            '7' {
                Invoke-PwWorkshopMenuAction -Action History |
                    Format-Table `
                        Timestamp,
                        Type,
                        Profile,
                        Status,
                        FileCount
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

        if ($running) {
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

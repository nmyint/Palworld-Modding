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
                        Show-PwCatalogMods -Catalog $catalog
                        continue
                    }

                    if ($catalogChoice -match '^(?i:W)$') {
                        Show-PwCatalogWarnings -Catalog $catalog
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
                            $metadata |
                                Select-Object `
                                    CatalogKey,
                                    NexusModId,
                                    RemoteName,
                                    RemoteVersion,
                                    NameMatch,
                                    Status |
                                Format-Table -AutoSize
                            $applyMetadata = Read-Host (
                                '[A] Store metadata, [V] Verify ReviewIdentity, ' +
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
                                    $reviewItems |
                                        Select-Object `
                                            @{Name = '#'; Expression = {
                                                1 + $reviewItems.IndexOf($_)
                                            }},
                                            CatalogKey,
                                            InstallNames,
                                            NexusModId,
                                            RemoteName,
                                            RemoteVersion |
                                        Format-Table -AutoSize
                                    $reviewKey = Read-Host (
                                        'Review # to verify, [B] Back, ' +
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
                                                '[A] Approve this Nexus name as ' +
                                                    'an identity alias, [B] Back, ' +
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
                                    ReconciliationStatus |
                                Format-Table -AutoSize
                            $catalogChoice = Read-Host (
                                'Enter # to edit, [B] Back, or Q to quit'
                            )

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
                                        'Nexus mod ID (Enter to retain current, ' +
                                            '[B] Back)'
                                    )
                                    $displayName = Read-Host (
                                        'Display name (Enter to retain current, ' +
                                            '[B] Back)'
                                    )
                                    $installedVersion = Read-Host (
                                        'Installed version (Enter to retain current, ' +
                                            '[B] Back)'
                                    )
                                    $identity = $null

                                    if (
                                        (Test-PwWorkshopBackSelection $nexusId) -or
                                        (Test-PwWorkshopBackSelection $displayName) -or
                                        (Test-PwWorkshopBackSelection $installedVersion)
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
                                        '[A] Apply entered identity fields, ' +
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
                        $reconciliation.Groups |
                            Select-Object `
                                DisplayName,
                                @{Name = 'PackageTypes'; Expression = {
                                    @($_.PackageTypes) -join ', '
                                }},
                                ComponentCount,
                                IsMixedPackage |
                            Format-Table -AutoSize
                        Write-Host ''
                        $reconciliation |
                            Select-Object `
                                ComponentCount,
                                MatchedComponentCount,
                                MixedPackageCount,
                                ReviewItemCount |
                            Format-List

                        if ($reconciliation.ReviewItemCount -gt 0) {
                            Write-Host 'Ownership review required:' `
                                -ForegroundColor Yellow
                            $reconciliation.ReviewItems |
                                Select-Object `
                                    OwnerName,
                                    SourceArea,
                                    PackageType,
                                    RelativePath |
                                Format-Table -AutoSize
                        }

                        continue
                    }
                }
            }
            '2' {
                $archiveMenuActive = $true

                while ($archiveMenuActive) {
                    $archives = @(
                        Invoke-PwWorkshopMenuAction -Action Archives
                    )
                    $archives |
                        Format-Table `
                            Name,
                            NexusModId,
                            ArchiveVersion,
                            DownloadedAt,
                            InstallNames
                    $archiveChoice = Read-Host (
                        '[I] Inspect and import an archive, [B] Back, ' +
                            'or Q to quit'
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
                                'Archive path, filename from 01_Archives, or Q'
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
                                $inspection.Entries |
                                    Where-Object { -not $_.IsDirectory } |
                                    Select-Object `
                                        ArchivePath,
                                        Category,
                                        DeploymentRelativePath,
                                        ReviewRequired |
                                    Format-Table -AutoSize
                                $inspection |
                                    Select-Object `
                                        Format,
                                        IsSafe,
                                        RequiresReview,
                                        FileCount,
                                        TotalUncompressedBytes |
                                    Format-List

                                if (-not $inspection.IsSafe) {
                                    throw (
                                        'Archive failed safety inspection: ' +
                                            ($inspection.Errors -join ' ')
                                    )
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
                Invoke-PwWorkshopMenuAction -Action Staging |
                    Format-Table Name, Enabled, EnabledSource, Types, FileCount
            }
            '4' {
                $updatesMenuActive = $true

                while ($updatesMenuActive) {
                    try {
                        $updates = @(
                            Invoke-PwWorkshopMenuAction -Action Updates
                        )
                        Show-PwUpdateReport -Updates $updates
                        Write-Host ''
                        Write-Host 'Configured tool and dependency sources:'
                        $sourceUpdates = @(
                            Invoke-PwWorkshopMenuAction -Action SourceUpdates
                        )
                        $sourceUpdates |
                            Select-Object `
                                Name,
                                Provider,
                                LocalVersion,
                                RemoteVersion,
                                Status |
                            Format-Table -AutoSize
                        $selectedId = Read-Host (
                            'Enter Nexus mod ID, [B] record UE4SS baseline, ' +
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

                        if ($selectedId -match '^(?i:B)$') {
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

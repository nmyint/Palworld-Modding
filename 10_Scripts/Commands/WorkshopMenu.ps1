<#
.SYNOPSIS
    Provides the interactive Palworld Modding Workshop menu.
#>

Set-StrictMode -Version Latest

function Show-PwWorkshopMenuHeader {

    [CmdletBinding()]
    param()

    $configuration = Get-PwWorkshopConfig
    $environment = Test-PwEnvironment

    Write-Host ''
    Write-Host '==================================================' `
        -ForegroundColor Cyan
    Write-Host ' Palworld Modding Workshop' -ForegroundColor Cyan
    Write-Host " Profile: $($configuration.Deployment.ActiveProfile)"
    Write-Host " Environment: $(if ($environment.IsReady) {
        'Ready'
    }
    else {
        'Needs attention'
    })"
    Write-Host '==================================================' `
        -ForegroundColor Cyan
    Write-Host ''
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
            'Archives',
            'Staging',
            'Updates',
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
        'Archives' {
            return @(Get-PwNexusArchiveMetadata)
        }
        'Staging' {
            return @(Get-PwStagedModSnapshot)
        }
        'Updates' {
            return @(Get-PwModUpdateReport)
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
            'Archives',
            'Staging',
            'Updates',
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
        if (-not $NoClear) {
            Clear-Host
        }

        Show-PwWorkshopMenuHeader
        Write-Host ' MOD CATALOG'
        Write-Host '  1. View catalog and version matches'
        Write-Host '  2. View Nexus archive metadata'
        Write-Host '  3. View loose staging snapshot'
        Write-Host '  4. Check Nexus for updates'
        Write-Host ''
        Write-Host ' WORKSHOP HEALTH'
        Write-Host '  5. Run diagnostics'
        Write-Host '  6. View known-good installation inventory'
        Write-Host '  7. View deployment and restore history'
        Write-Host ''
        Write-Host '  Q. Exit'
        Write-Host ''
        $selection = Read-Host 'Select an option'

        if (-not $NoClear) {
            Clear-Host
        }

        switch ($selection.ToUpperInvariant()) {
            '1' {
                Show-PwCatalogSummary -Catalog (
                    Invoke-PwWorkshopMenuAction -Action Catalog
                )
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
                    $selectedId = Read-Host (
                        'Enter a Nexus mod ID for download options, or Enter ' +
                        'to return'
                    )

                    if ($selectedId -match '^\d+$') {
                        $selected = $updates |
                            Where-Object NexusModId -eq ([int]$selectedId) |
                            Select-Object -First 1

                        if (-not $selected) {
                            Write-Host 'Mod ID is not in this report.' `
                                -ForegroundColor Yellow
                        }
                        else {
                            $mode = Read-Host (
                                '[M]anual browser or [D]irect Premium download'
                            )

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

        if ($running) {
            Write-Host ''
            Read-Host 'Press Enter to return to the menu' | Out-Null
        }
    }
}

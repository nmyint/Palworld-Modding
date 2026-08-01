<#
.SYNOPSIS
    Verifies the dashboard-driven workshop menu integration.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding workshop menu dashboard integration' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'renders durable labels and dashboard state without provider duplication' {
        InModuleScope PalworldModding {
            $dashboard = [PSCustomObject]@{
                Profile = [PSCustomObject]@{
                    Name = 'Stable'
                    IsReady = $true
                    IsValid = $true
                    ActiveModSet = 'Core'
                    SelectedModCount = 3
                }
                Repository = [PSCustomObject]@{
                    Branch = 'main'
                    IsClean = $true
                    Changes = @()
                    HasUpstream = $true
                    Ahead = 0
                    Behind = 0
                }
                Catalog = [PSCustomObject]@{ ModCount = 12 }
                Deployment = [PSCustomObject]@{ CanDeploy = $false }
                UpdateCache = [PSCustomObject]@{
                    Exists = $true
                    IsCurrent = $false
                }
                Diagnostics = [PSCustomObject]@{ IsHealthy = $true }
                ReadySectionCount = 7
                Sections = @(1..7)
            }

            $text = @(
                Get-PwWorkshopMenuLayout `
                    -Dashboard $dashboard `
                    -Width 110 `
                    -Height 32
            ).Text -join "`n"

            $text | Should Match 'WORKSHOP CONTROL CENTER'
            $text | Should Match 'Stable: Ready, Core \(3 mods\)'
            $text | Should Match 'main: clean, synced'
            $text | Should Match 'Catalog 12 mods'
            $text | Should Match 'Deploy blocked'
            $text | Should Match 'Updates stale'
            $text | Should Match 'Diagnostics healthy'
            $text | Should Not Match 'Sprint 4'
        }
    }

    It 'collects exactly one dashboard snapshot for each menu render' {
        InModuleScope PalworldModding {
            Mock Get-PwWorkshopDashboard {
                [PSCustomObject]@{
                    Profile = $null
                    Repository = $null
                    Catalog = $null
                    Deployment = $null
                    UpdateCache = $null
                    Diagnostics = $null
                    ReadySectionCount = 0
                    Sections = @(1..7)
                }
            }
            Mock Get-PwWorkshopTerminalSize {
                [PSCustomObject]@{ Width = 80; Height = 24 }
            }
            Mock Write-Host {}

            Show-PwWorkshopMenu

            Assert-MockCalled Get-PwWorkshopDashboard -Times 1 -Exactly
        }
    }

    It 'accepts every displayed main-menu key' {
        $menu = Get-Content `
            -LiteralPath (Join-Path $PSScriptRoot '..\Commands\WorkshopMenu.ps1') `
            -Raw

        $menu | Should Match "@\('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'Q'\)"
    }
}

<#
.SYNOPSIS
    Verifies the structured, read-only workshop dashboard data model.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding workshop dashboard model' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'uses existing read-only providers and never invokes mutation commands' {
        InModuleScope PalworldModding {
            Mock Get-PwWorkshopInfo {
                [PSCustomObject]@{
                    Name = 'Workshop'
                    Version = '0.4.9'
                    Root = $TestDrive
                }
            }
            Mock Get-PwDashboardRepositoryState {
                [PSCustomObject]@{
                    Root = $TestDrive
                    Branch = 'test'
                    IsClean = $true
                    Ahead = 0
                    Behind = 0
                }
            }
            Mock Get-PwWorkshopConfig {
                [PSCustomObject]@{
                    Deployment = [PSCustomObject]@{
                        ActiveProfile = 'Stable'
                    }
                }
            }
            Mock Get-PwProfile {
                [PSCustomObject]@{
                    Name = 'Stable'
                    Description = 'Stable profile'
                    Game = [PSCustomObject]@{
                        Platform = 'Steam'
                    }
                }
            }
            Mock Test-PwProfile {
                [PSCustomObject]@{
                    Name = 'Stable'
                    IsValid = $true
                    IsReady = $true
                    Errors = @()
                    Warnings = @()
                }
            }
            Mock Get-PwProfileModSetPreview {
                [PSCustomObject]@{
                    Profile = 'Stable'
                    ModSet = 'Core'
                    ModCount = 2
                    Mods = @(
                        [PSCustomObject]@{
                            CatalogKey = 'zulu'
                            DisplayName = 'Zulu'
                            InstalledVersion = '2.0'
                            ReconciliationStatus = 'Matched'
                            Types = @('Pak')
                        }
                        [PSCustomObject]@{
                            CatalogKey = 'alpha'
                            DisplayName = 'Alpha'
                            InstalledVersion = '1.0'
                            ReconciliationStatus = 'Matched'
                            Types = @('UE4SS')
                        }
                    )
                }
            }
            Mock Get-PwCatalogManifestPath {
                Join-Path $TestDrive 'catalog.json'
            }
            Mock Get-PwPersistentModCatalog {
                [PSCustomObject]@{
                    SchemaVersion = '1.0'
                    UpdatedAt = '2026-08-01T00:00:00Z'
                    Mods = @(
                        [PSCustomObject]@{
                            CatalogKey = 'zulu'
                            DisplayName = 'Zulu'
                            Source = 'NexusMods'
                            Enabled = $true
                            InstalledVersion = '2.0'
                            ReconciliationStatus = 'Matched'
                            NexusModIds = @(2)
                            Types = @('Pak')
                            Versions = @(
                                [PSCustomObject]@{
                                    ArchivePresent = $false
                                }
                            )
                        }
                        [PSCustomObject]@{
                            CatalogKey = 'alpha'
                            DisplayName = 'Alpha'
                            Source = 'Local'
                            Enabled = $true
                            InstalledVersion = '1.0'
                            ReconciliationStatus = 'Matched'
                            NexusModIds = @()
                            Types = @('UE4SS')
                            Versions = @(
                                [PSCustomObject]@{
                                    ArchivePresent = $true
                                }
                            )
                        }
                    )
                }
            }
            Mock Get-PwDeployment {
                [PSCustomObject]@{
                    ActiveProfile = 'Stable'
                    TargetRoot = (Join-Path $TestDrive 'Deployment')
                    GameInstallRoot = ''
                    GameExecutable = ''
                    SavedRoot = ''
                    IsReady = $false
                    CanDeploy = $false
                    Warnings = @('Game path is unavailable.')
                }
            }
            Mock Get-PwProfileAssemblyPlan {
                [PSCustomObject]@{
                    Profile = 'Stable'
                    ModSet = 'Core'
                    CanBuild = $true
                    PackageCount = 2
                    FileCount = 2
                }
            }
            Mock Test-PwProfileDeploymentAssembly {
                [PSCustomObject]@{
                    Profile = 'Stable'
                    IsValid = $false
                    FileCount = 0
                    Errors = @('Assembly manifest was not found.')
                }
            }
            Mock Test-PwDeploymentReadiness {
                throw 'Readiness should not run when deployment is unavailable.'
            }
            Mock Get-PwNexusMetadataCacheInfo {
                [PSCustomObject]@{
                    Exists = $false
                    CatalogModCount = 1
                    CachedModCount = 0
                    IsComplete = $false
                    IsCurrent = $false
                }
            }
            Mock Get-PwDiagnostics {
                [PSCustomObject]@{
                    IsHealthy = $true
                    Warnings = @()
                }
            }

            Mock Update-PwNexusMetadataCache {}
            Mock Update-PwModCatalog {}
            Mock Build-PwProfileDeployment {}
            Mock Invoke-PwDeployment {}
            Mock Restore-PwDeployment {}

            $result = Get-PwWorkshopDashboard
            $profileSection = $result.Sections |
                Where-Object Name -eq 'Profile' |
                Select-Object -First 1

            $profileSection.Status | Should Be 'Ready'
            $profileSection.Error | Should Be ''
            $result.Profile.SelectedMods[0].CatalogKey | Should Be 'alpha'
            $result.Catalog.Items[0].CatalogKey | Should Be 'alpha'
            $result.Catalog.Items[0].PresentArchiveCount | Should Be 1
            $result.Catalog.Items[1].PresentArchiveCount | Should Be 0
            $result.Deployment.AssemblyPlanStatus | Should Be 'Ready'
            $result.Deployment.AssemblyValidationStatus | Should Be 'Ready'
            $result.Deployment.ReadinessStatus | Should Be 'NotEvaluated'

            Assert-MockCalled Test-PwDeploymentReadiness -Times 0 -Exactly
            Assert-MockCalled Update-PwNexusMetadataCache -Times 0 -Exactly
            Assert-MockCalled Update-PwModCatalog -Times 0 -Exactly
            Assert-MockCalled Build-PwProfileDeployment -Times 0 -Exactly
            Assert-MockCalled Invoke-PwDeployment -Times 0 -Exactly
            Assert-MockCalled Restore-PwDeployment -Times 0 -Exactly
        }
    }

    It 'returns a deterministic structured snapshot with fixed section order' {
        InModuleScope PalworldModding {
            $generatedAt = [datetime]'2026-08-01T12:00:00Z'

            Mock Get-PwWorkshopInfo {
                [PSCustomObject]@{ Name = 'Workshop'; Version = '0.4.9' }
            }
            Mock Get-PwDashboardRepositoryState {
                [PSCustomObject]@{ Branch = 'test'; IsClean = $true }
            }
            Mock Get-PwDashboardProfileState {
                [PSCustomObject]@{ Name = 'Stable'; IsReady = $true }
            }
            Mock Get-PwDashboardCatalogState {
                [PSCustomObject]@{ ModCount = 2 }
            }
            Mock Get-PwDashboardDeploymentState {
                [PSCustomObject]@{ CanDeploy = $true }
            }
            Mock Get-PwNexusMetadataCacheInfo {
                [PSCustomObject]@{ Exists = $true; IsCurrent = $true }
            }
            Mock Get-PwDiagnostics {
                [PSCustomObject]@{ IsHealthy = $true }
            }

            $result = Get-PwWorkshopDashboard -GeneratedAt $generatedAt

            $result.SchemaVersion | Should Be '1.0'
            $result.GeneratedAt.ToUniversalTime() |
                Should Be $generatedAt.ToUniversalTime()
            ($result.Sections.Name -join ',') | Should Be (
                'Workshop,Repository,Profile,Catalog,Deployment,' +
                'UpdateCache,Diagnostics'
            )
            @($result.Sections | Where-Object Status -ne 'Ready').Count |
                Should Be 0
            $result.ReadySectionCount | Should Be 7
            $result.UnavailableSectionCount | Should Be 0
            $result.IsComplete | Should Be $true
            @($result.Errors).Count | Should Be 0
            $result.Workshop.Name | Should Be 'Workshop'
            $result.Repository.Branch | Should Be 'test'
            $result.Profile.Name | Should Be 'Stable'
            $result.Catalog.ModCount | Should Be 2
            $result.Deployment.CanDeploy | Should Be $true
            $result.UpdateCache.IsCurrent | Should Be $true
            $result.Diagnostics.IsHealthy | Should Be $true

            { $result | ConvertTo-Json -Depth 30 } | Should Not Throw
        }
    }

    It 'isolates one unavailable provider without discarding other sections' {
        InModuleScope PalworldModding {
            Mock Get-PwWorkshopInfo {
                [PSCustomObject]@{ Name = 'Workshop' }
            }
            Mock Get-PwDashboardRepositoryState {
                [PSCustomObject]@{ Branch = 'test' }
            }
            Mock Get-PwDashboardProfileState {
                [PSCustomObject]@{ Name = 'Stable' }
            }
            Mock Get-PwDashboardCatalogState {
                [PSCustomObject]@{ ModCount = 2 }
            }
            Mock Get-PwDashboardDeploymentState {
                [PSCustomObject]@{ CanDeploy = $false }
            }
            Mock Get-PwNexusMetadataCacheInfo {
                throw 'Cache is unreadable.'
            }
            Mock Get-PwDiagnostics {
                [PSCustomObject]@{ IsHealthy = $true }
            }

            $result = Get-PwWorkshopDashboard
            $cacheSection = $result.Sections |
                Where-Object Name -eq 'UpdateCache' |
                Select-Object -First 1

            $result.Workshop.Name | Should Be 'Workshop'
            $result.Repository.Branch | Should Be 'test'
            $result.UpdateCache | Should BeNullOrEmpty
            $cacheSection.Status | Should Be 'Unavailable'
            $cacheSection.Error | Should Be 'Cache is unreadable.'
            $result.ReadySectionCount | Should Be 6
            $result.UnavailableSectionCount | Should Be 1
            $result.IsComplete | Should Be $false
            $result.Errors[0].Section | Should Be 'UpdateCache'
            $result.Errors[0].Message | Should Be 'Cache is unreadable.'
        }
    }
}

Describe 'PalworldModding dashboard menu integration' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'maps dashboard providers into a clear menu state summary' {
        InModuleScope PalworldModding {
            $dashboard = [PSCustomObject]@{
                IsComplete = $true
                ReadySectionCount = 7
                Sections = @(
                    'Workshop',
                    'Repository',
                    'Profile',
                    'Catalog',
                    'Deployment',
                    'UpdateCache',
                    'Diagnostics'
                ) | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_
                        Status = 'Ready'
                        Error = ''
                    }
                }
                Profile = [PSCustomObject]@{
                    Name = 'Stable'
                    IsValid = $true
                    IsReady = $true
                    ActiveModSet = 'Core'
                    SelectedModCount = 12
                }
                Repository = [PSCustomObject]@{
                    Branch = 'main'
                    IsClean = $true
                    HasUpstream = $true
                    Ahead = 0
                    Behind = 0
                    Changes = @()
                }
                Catalog = [PSCustomObject]@{
                    ModCount = 20
                    EnabledCount = 12
                    WithNexusIdCount = 18
                }
                Deployment = [PSCustomObject]@{
                    IsReady = $true
                    CanDeploy = $true
                    AssemblyPlanStatus = 'Ready'
                    AssemblyValidationStatus = 'Ready'
                }
                UpdateCache = [PSCustomObject]@{
                    Exists = $true
                    IsComplete = $true
                    IsCurrent = $true
                }
                Diagnostics = [PSCustomObject]@{
                    IsHealthy = $true
                }
            }

            $state = Get-PwWorkshopMenuDashboardState -Dashboard $dashboard

            $state.ProfileName | Should Be 'Stable'
            $state.ProfileStatus | Should Be 'Ready'
            $state.ActiveModSet | Should Be 'Core'
            $state.SelectedModCount | Should Be 12
            $state.Branch | Should Be 'main'
            $state.RepositoryStatus | Should Be 'Clean'
            $state.RepositorySync | Should Be 'Synchronized'
            $state.CatalogStatus | Should Match '20 mods'
            $state.DeploymentStatus | Should Be 'Ready to deploy'
            $state.UpdateCacheStatus | Should Be 'Current'
            $state.DiagnosticsStatus | Should Be 'Healthy'
            $state.CollectionStatus | Should Be 'Complete (7/7)'
        }
    }

    It 'renders durable dashboard-aware full and compact menu layouts' {
        InModuleScope PalworldModding {
            $dashboard = [PSCustomObject]@{
                IsComplete = $true
                ReadySectionCount = 7
                Sections = @(
                    'Workshop',
                    'Repository',
                    'Profile',
                    'Catalog',
                    'Deployment',
                    'UpdateCache',
                    'Diagnostics'
                ) | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_
                        Status = 'Ready'
                        Error = ''
                    }
                }
                Profile = [PSCustomObject]@{
                    Name = 'Stable'
                    IsValid = $true
                    IsReady = $true
                    ActiveModSet = 'Core'
                    SelectedModCount = 12
                }
                Repository = [PSCustomObject]@{
                    Branch = 'main'
                    IsClean = $true
                    HasUpstream = $true
                    Ahead = 0
                    Behind = 0
                    Changes = @()
                }
                Catalog = [PSCustomObject]@{
                    ModCount = 20
                    EnabledCount = 12
                    WithNexusIdCount = 18
                }
                Deployment = [PSCustomObject]@{
                    IsReady = $true
                    CanDeploy = $true
                    AssemblyPlanStatus = 'Ready'
                    AssemblyValidationStatus = 'Ready'
                }
                UpdateCache = [PSCustomObject]@{
                    Exists = $true
                    IsComplete = $true
                    IsCurrent = $true
                }
                Diagnostics = [PSCustomObject]@{
                    IsHealthy = $true
                }
            }

            $full = Get-PwWorkshopMenuLayout `
                -Dashboard $dashboard `
                -Width 100 `
                -Height 30
            $compact = Get-PwWorkshopMenuLayout `
                -Dashboard $dashboard `
                -Width 60 `
                -Height 18
            $fullText = @($full.Text) -join "`n"
            $compactText = @($compact.Text) -join "`n"

            $fullText | Should Match 'Guided workshop operations and current state'
            $fullText | Should Match '\[H\] View current state dashboard'
            $fullText | Should Match 'Profile    : Stable'
            $fullText | Should Match 'Repository : main'
            $fullText.Contains('Sprint 4') | Should Be $false
            $compactText | Should Match '\[H\] Current state dashboard'
            $compactText | Should Match '\[9\] Inventory'
            $compactText | Should Match '\[0\] History'
            (@($compact).Count -le 18) | Should Be $true
        }
    }

    It 'collects the dashboard once for the main menu and avoids legacy probes' {
        InModuleScope PalworldModding {
            $dashboard = [PSCustomObject]@{
                IsComplete = $false
                ReadySectionCount = 0
                Sections = @()
            }

            Mock Get-PwWorkshopDashboard { $dashboard }
            Mock Get-PwWorkshopTerminalSize {
                [PSCustomObject]@{ Width = 80; Height = 24 }
            }
            Mock Get-PwWorkshopConfig {
                throw 'Legacy configuration probe should not run.'
            }
            Mock Test-PwEnvironment {
                throw 'Legacy environment probe should not run.'
            }
            Mock Write-Host {}

            Show-PwWorkshopMenu

            Assert-MockCalled Get-PwWorkshopDashboard -Times 1 -Exactly
            Assert-MockCalled Get-PwWorkshopConfig -Times 0 -Exactly
            Assert-MockCalled Test-PwEnvironment -Times 0 -Exactly
        }
    }

    It 'keeps the detailed dashboard view read-only' {
        InModuleScope PalworldModding {
            $dashboard = [PSCustomObject]@{
                GeneratedAt = [datetime]'2026-08-01T12:00:00Z'
                IsComplete = $true
                ReadySectionCount = 7
                Sections = @(
                    'Workshop',
                    'Repository',
                    'Profile',
                    'Catalog',
                    'Deployment',
                    'UpdateCache',
                    'Diagnostics'
                ) | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_
                        Status = 'Ready'
                        Error = ''
                    }
                }
                Errors = @()
                Profile = [PSCustomObject]@{
                    Name = 'Stable'
                    IsValid = $true
                    IsReady = $true
                    ActiveModSet = 'Core'
                    SelectedModCount = 12
                }
                Repository = [PSCustomObject]@{
                    Branch = 'main'
                    IsClean = $true
                    HasUpstream = $true
                    Ahead = 0
                    Behind = 0
                    Changes = @()
                }
                Catalog = [PSCustomObject]@{
                    ModCount = 20
                    EnabledCount = 12
                    WithNexusIdCount = 18
                }
                Deployment = [PSCustomObject]@{
                    IsReady = $true
                    CanDeploy = $true
                    AssemblyPlanStatus = 'Ready'
                    AssemblyValidationStatus = 'Ready'
                }
                UpdateCache = [PSCustomObject]@{
                    Exists = $true
                    IsComplete = $true
                    IsCurrent = $true
                }
                Diagnostics = [PSCustomObject]@{
                    IsHealthy = $true
                }
            }

            Mock Get-PwWorkshopTerminalSize {
                [PSCustomObject]@{ Width = 100; Height = 30 }
            }
            Mock Clear-Host {}
            Mock Write-Host {}
            Mock Update-PwNexusMetadataCache {}
            Mock Update-PwModCatalog {}
            Mock Build-PwProfileDeployment {}
            Mock Invoke-PwDeployment {}
            Mock Restore-PwDeployment {}

            Show-PwWorkshopDashboard -Dashboard $dashboard

            Assert-MockCalled Update-PwNexusMetadataCache -Times 0 -Exactly
            Assert-MockCalled Update-PwModCatalog -Times 0 -Exactly
            Assert-MockCalled Build-PwProfileDeployment -Times 0 -Exactly
            Assert-MockCalled Invoke-PwDeployment -Times 0 -Exactly
            Assert-MockCalled Restore-PwDeployment -Times 0 -Exactly
        }
    }
}

<#
.SYNOPSIS
    Verifies profile assembly planning and deployment path conflicts.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding profile assembly planning' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force

        $global:PwAssemblyLibraryRoot = Join-Path `
            $TestDrive `
            '03_Mod_Library'

        $global:PwAssemblyDeploymentRoot = Join-Path `
            $TestDrive `
            '05_Deployment'

        InModuleScope PalworldModding {
            Mock Get-PwWorkshopConfig {
                [PSCustomObject]@{
                    Deployment = [PSCustomObject]@{
                        ActiveProfile = 'Test'
                    }
                }
            }

            Mock Get-PwDeployment {
                [PSCustomObject]@{
                    TargetRoot = $global:PwAssemblyDeploymentRoot
                }
            }

            Mock Get-PwModPackageRoot {
                param(
                    $Area,
                    $Name,
                    $Version
                )

                Join-Path `
                    $global:PwAssemblyLibraryRoot `
                    ('{0}\{1}' -f $Name, $Version)
            }

            Mock Get-PwContentSetHash {
                param($Entries)

                @($Entries.Hash) -join ':'
            }
        }
    }

    AfterAll {
        Remove-Variable `
            PwAssemblyLibraryRoot `
            -Scope Global `
            -ErrorAction SilentlyContinue

        Remove-Variable `
            PwAssemblyDeploymentRoot `
            -Scope Global `
            -ErrorAction SilentlyContinue
    }

    It 'allows distinct deployment paths from multiple packages' {

        InModuleScope PalworldModding {
            Mock Get-PwProfileModSetPreview {
                [PSCustomObject]@{
                    ModSet = 'Default'
                    Mods = @(
                        [PSCustomObject]@{
                            CatalogKey = 'mod-one'
                        }
                        [PSCustomObject]@{
                            CatalogKey = 'mod-two'
                        }
                    )
                }
            }

            Mock Get-PwPersistentModCatalog {
                [PSCustomObject]@{
                    Mods = @(
                        [PSCustomObject]@{
                            CatalogKey = 'mod-one'
                            InstalledVersion = '1.0'
                        }
                        [PSCustomObject]@{
                            CatalogKey = 'mod-two'
                            InstalledVersion = '1.0'
                        }
                    )
                }
            }

            Mock Get-PwStagingReconciliation {
                [PSCustomObject]@{
                    StagingRoot = '02_Staging'
                    ReviewItemCount = 0
                    Groups = @(
                        [PSCustomObject]@{
                            CatalogKey = 'mod-one'
                            DisplayName = 'Mod One'
                            PackageTypes = @('UE4SSLua')
                            Components = @(
                                [PSCustomObject]@{
                                    RelativePath = (
                                        'Pal\Binaries\Win64\ue4ss\Mods\' +
                                        'ModOne\Scripts\main.lua'
                                    )
                                    Hash = 'hash-one'
                                }
                            )
                        }
                        [PSCustomObject]@{
                            CatalogKey = 'mod-two'
                            DisplayName = 'Mod Two'
                            PackageTypes = @('UE4SSLua')
                            Components = @(
                                [PSCustomObject]@{
                                    RelativePath = (
                                        'Pal\Binaries\Win64\ue4ss\Mods\' +
                                        'ModTwo\Scripts\main.lua'
                                    )
                                    Hash = 'hash-two'
                                }
                            )
                        }
                    )
                }
            }

            $plan = Get-PwProfileAssemblyPlan -ProfileName 'Test'

            $plan.PackageConflictCount | Should Be 0
            $plan.PathConflictCount | Should Be 0
            $plan.ConflictCount | Should Be 0
            $plan.PathConflicts.Count | Should Be 0
            $plan.CanBuild | Should Be $true
        }
    }

    It 'blocks case-insensitive deployment path collisions' {

        InModuleScope PalworldModding {
            Mock Get-PwProfileModSetPreview {
                [PSCustomObject]@{
                    ModSet = 'Default'
                    Mods = @(
                        [PSCustomObject]@{
                            CatalogKey = 'mod-one'
                        }
                        [PSCustomObject]@{
                            CatalogKey = 'mod-two'
                        }
                    )
                }
            }

            Mock Get-PwPersistentModCatalog {
                [PSCustomObject]@{
                    Mods = @(
                        [PSCustomObject]@{
                            CatalogKey = 'mod-one'
                            InstalledVersion = '1.0'
                        }
                        [PSCustomObject]@{
                            CatalogKey = 'mod-two'
                            InstalledVersion = '1.0'
                        }
                    )
                }
            }

            Mock Get-PwStagingReconciliation {
                [PSCustomObject]@{
                    StagingRoot = '02_Staging'
                    ReviewItemCount = 0
                    Groups = @(
                        [PSCustomObject]@{
                            CatalogKey = 'mod-one'
                            DisplayName = 'Mod One'
                            PackageTypes = @('Pak')
                            Components = @(
                                [PSCustomObject]@{
                                    RelativePath = (
                                        'Pal\Content\Paks\~mods\SharedMod.pak'
                                    )
                                    Hash = 'hash-one'
                                }
                            )
                        }
                        [PSCustomObject]@{
                            CatalogKey = 'mod-two'
                            DisplayName = 'Mod Two'
                            PackageTypes = @('Pak')
                            Components = @(
                                [PSCustomObject]@{
                                    RelativePath = (
                                        'pal/content/paks/~mods/sharedmod.pak'
                                    )
                                    Hash = 'hash-two'
                                }
                            )
                        }
                    )
                }
            }

            $plan = Get-PwProfileAssemblyPlan -ProfileName 'Test'
            $conflict = $plan.PathConflicts |
                Select-Object -First 1

            $plan.PackageConflictCount | Should Be 0
            $plan.PathConflictCount | Should Be 1
            $plan.ConflictCount | Should Be 1
            $plan.CanBuild | Should Be $false

            $conflict.RelativePath |
                Should Be 'Content\Paks\~mods\SharedMod.pak'

            @($conflict.CatalogKeys).Count | Should Be 2
            @($conflict.CatalogKeys) -contains 'mod-one' | Should Be $true
            @($conflict.CatalogKeys) -contains 'mod-two' | Should Be $true

            @($conflict.Hashes).Count | Should Be 2
            @($conflict.Hashes) -contains 'hash-one' | Should Be $true
            @($conflict.Hashes) -contains 'hash-two' | Should Be $true
        }
    }
}

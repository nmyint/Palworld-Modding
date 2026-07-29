<#
.SYNOPSIS
    Verifies mixed UE4SS and PAK staging reconciliation.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding staging reconciliation' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force

        $global:PwReconcileRoot = Join-Path $TestDrive '02_Staging'
        $luaRoot = Join-Path `
            $global:PwReconcileRoot `
            'Pal\Binaries\Win64\ue4ss\Mods\MixedMod\Scripts'
        $logicRoot = Join-Path (
            Join-Path $global:PwReconcileRoot 'Pal\Content\Paks\LogicMods'
        ) 'MixedMod'
        $loosePakRoot = Join-Path (
            $global:PwReconcileRoot
        ) 'Pal\Content\Paks\~mods'
        New-Item -ItemType Directory -Path $luaRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $logicRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $loosePakRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $luaRoot 'main.lua') -Value 'lua'
        Set-Content -LiteralPath (Join-Path $luaRoot 'runtime.log') -Value 'log'
        Set-Content `
            -LiteralPath (Join-Path (Split-Path $logicRoot) 'MixedMod.pak') `
            -Value 'pak'
        Set-Content `
            -LiteralPath (Join-Path $logicRoot 'config.lua') `
            -Value 'config'
        Set-Content `
            -LiteralPath (Join-Path $loosePakRoot 'UnknownMod_P.pak') `
            -Value 'unknown'

        InModuleScope PalworldModding {
            Mock Get-PwPersistentModCatalog {
                [PSCustomObject]@{
                    Mods = @(
                        [PSCustomObject]@{
                            CatalogKey = 'mixedmod'
                            DisplayName = 'MixedMod'
                            InstallNames = @('MixedMod')
                            ComponentNames = @('MixedConfig')
                        }
                    )
                }
            }
        }
    }

    AfterAll {
        Remove-Variable `
            PwReconcileRoot `
            -Scope Global `
            -ErrorAction SilentlyContinue
    }

    It 'groups Lua and LogicMods components under one catalog identity' {
        $result = Get-PwStagingReconciliation `
            -Path $global:PwReconcileRoot
        $mixed = $result.Groups |
            Where-Object CatalogKey -eq 'mixedmod'

        $result.ComponentCount | Should Be 4
        $result.MatchedComponentCount | Should Be 3
        $result.MixedPackageCount | Should Be 1
        $result.ReviewItemCount | Should Be 1
        $result.ExcludedItemCount | Should Be 1
        $result.ExcludedItems[0].Reason | Should Be 'RuntimeState'
        $mixed.IsMixedPackage | Should Be $true
        @($mixed.PackageTypes) -contains 'UE4SSLua' | Should Be $true
        @($mixed.PackageTypes) -contains 'LogicMods' | Should Be $true
    }

    It 'keeps unowned PAK files as explicit review items' {
        $result = Get-PwStagingReconciliation `
            -Path $global:PwReconcileRoot
        $review = $result.ReviewItems | Select-Object -First 1

        $review.OwnerName | Should Be 'UnknownMod'
        $review.PackageType | Should Be 'Pak'
        $review.OwnershipStatus | Should Be 'Unmatched'
    }

    It 'surfaces compatibility hints from staging and catalog metadata' {
        InModuleScope PalworldModding {
            Mock Get-PwStagingReconciliation {
                [PSCustomObject]@{
                    ReviewItemCount = 1
                    Groups = @(
                        [PSCustomObject]@{
                            CatalogKey = 'mixedmod'
                            DisplayName = 'MixedMod'
                            PackageTypes = @('UE4SSLua', 'LogicMods')
                            ComponentCount = 2
                            IsMixedPackage = $true
                        }
                    )
                    ReviewItems = @()
                }
            }

            Mock Get-PwPersistentModCatalog {
                [PSCustomObject]@{
                    Mods = @(
                        [PSCustomObject]@{
                            CatalogKey = 'example'
                            DisplayName = 'Example'
                            Versions = @(
                                [PSCustomObject]@{
                                    ArchiveHash = 'abc'
                                    Version = '1.0'
                                    Platform = 'Steam'
                                    PlayMode = 'Universal'
                                }
                                [PSCustomObject]@{
                                    ArchiveHash = 'abc'
                                    Version = '1.1'
                                    Platform = 'GamePass'
                                    PlayMode = 'DedicatedServer'
                                }
                            )
                        }
                    )
                }
            }

            $result = Get-PwCompatibilityReport -Path $global:PwReconcileRoot

            $result.ConflictCount | Should Be 0
            $result.ReviewCount | Should Be 3
            $result.DuplicateArchives.Count | Should Be 1
            $result.MixedPackages.Count | Should Be 1
            $result.VariantWarnings.Count | Should Be 1
        }
    }
}

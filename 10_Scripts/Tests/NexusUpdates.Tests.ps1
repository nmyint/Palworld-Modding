<#
.SYNOPSIS
    Verifies Nexus update reporting and safe download selection.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding Nexus updates' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force

        InModuleScope PalworldModding {
            Mock Invoke-PwNexusApi {
                param($Path, $ApiKey)

                switch -Regex ($Path) {
                    'mods/1234\.json$' {
                        return [PSCustomObject]@{
                            name = 'Example Mod'
                            version = '2.0'
                        }
                    }
                    'mods/1234/files\.json$' {
                        return [PSCustomObject]@{
                            files = @(
                                [PSCustomObject]@{
                                    file_id = 42
                                    file_name = 'Example-2.0.zip'
                                    version = '2.0'
                                    category_id = 1
                                    category_name = 'MAIN'
                                    uploaded_timestamp = 1782864000
                                }
                            )
                        }
                    }
                    'mods/3799\.json$' {
                        return [PSCustomObject]@{
                            name = 'AntiPhat - Pal Resize'
                            version = 'SP-2.0.6'
                        }
                    }
                    'mods/3799/files\.json$' {
                        return [PSCustomObject]@{
                            files = @(
                                [PSCustomObject]@{
                                    file_id = 100
                                    file_name = 'AntiPhat Dedicated'
                                    version = 'DS-2.0.17'
                                    category_id = 1
                                    category_name = 'MAIN'
                                    uploaded_timestamp = 1785200000
                                }
                                [PSCustomObject]@{
                                    file_id = 101
                                    file_name = 'AntiPhat Singleplayer'
                                    version = 'SP-2.0.5'
                                    category_id = 1
                                    category_name = 'MAIN'
                                    uploaded_timestamp = 1785100000
                                }
                            )
                        }
                    }
                    default {
                        throw "Unexpected mocked API path: $Path"
                    }
                }
            }
        }
    }

    It 'reports a newer Nexus main file without changing local files' {
        $archives = @(
            [PSCustomObject]@{
                IsParsed = $true
                NexusModId = 1234
                Name = 'Example Mod'
                ArchiveVersion = '1.0'
                DownloadedAt = [datetime]'2026-07-01T00:00:00Z'
            }
            [PSCustomObject]@{
                IsParsed = $false
                NexusModId = 0
                Name = 'Unknown Mod'
                ArchiveVersion = ''
                DownloadedAt = $null
            }
        )
        $result = @(
            Get-PwModUpdateReport `
                -ApiKey 'fixture-key' `
                -ArchiveMetadata $archives
        )

        $result.Count | Should Be 1
        $result[0].Status | Should Be 'UpdateAvailable'
        $result[0].RemoteVersion | Should Be '2.0'
        $result[0].RemoteFileId | Should Be 42
    }

    It 'returns a manual file page without launching it' {
        $result = Open-PwNexusModPage -ModId 1234

        $result | Should Be (
            'https://www.nexusmods.com/palworld/mods/1234?tab=files'
        )
    }

    It 'compares a singleplayer archive only with singleplayer files' {
        $archives = @(
            [PSCustomObject]@{
                IsParsed = $true
                NexusModId = 3799
                Name = 'AntiPhat'
                OriginalFileName = (
                    'AntiPhat (Singleplayer) 3799 SP-2.0.5.zip'
                )
                ArchiveVersion = 'SP-2.0.5'
                DownloadedAt = [datetime]'2026-07-26T02:09:00Z'
            }
        )
        $result = @(
            Get-PwModUpdateReport `
                -ApiKey 'fixture-key' `
                -ArchiveMetadata $archives
        )

        $result[0].LocalVariant | Should Be 'SinglePlayer'
        $result[0].RemoteVariant | Should Be 'SinglePlayer'
        $result[0].RemoteVersion | Should Be 'SP-2.0.5'
        $result[0].RemoteFileId | Should Be 101
        $result[0].RemoteVersion | Should Not Match '^DS-'
        $result[0].Status | Should Be 'Current'
    }

    It 'refuses direct downloads for a non-Premium account' {
        InModuleScope PalworldModding {
            Mock Get-PwNexusApiIdentity {
                [PSCustomObject]@{
                    is_premium = $false
                }
            }

            $threw = $false

            try {
                Save-PwNexusModUpdate `
                    -ModId 1234 `
                    -FileId 42 `
                    -ApiKey 'fixture-key' `
                    -Destination $TestDrive `
                    -Confirm:$false
            }
            catch {
                $threw = $true
            }

            $threw | Should Be $true
        }
    }

    It 'builds a profile mod download plan from the active mod set' {
        InModuleScope PalworldModding {
            Mock Get-PwProfileModSets {
                @(
                    [PSCustomObject]@{
                        Name = 'Core'
                        Description = 'Core mods'
                        IsActive = $true
                        CatalogKeys = @('examplemod', 'missingmod')
                    }
                )
            }

            Mock Get-PwPersistentModCatalog {
                [PSCustomObject]@{
                    Mods = @(
                        [PSCustomObject]@{
                            CatalogKey = 'examplemod'
                            DisplayName = 'Example Mod'
                            NexusModIds = @(1234)
                            ArchiveVersions = @(
                                [PSCustomObject]@{ ArchivePresent = $false }
                            )
                        }
                        [PSCustomObject]@{
                            CatalogKey = 'missingmod'
                            DisplayName = 'Missing ID Mod'
                            NexusModIds = @()
                            ArchiveVersions = @()
                        }
                    )
                }
            }

            Mock Invoke-PwNexusApi {
                param($Path, $ApiKey)

                switch -Regex ($Path) {
                    'mods/1234\.json$' {
                        [PSCustomObject]@{ name = 'Example Mod' }
                    }
                    'mods/1234/files\.json$' {
                        [PSCustomObject]@{
                            files = @(
                                [PSCustomObject]@{
                                    file_id = 42
                                    file_name = 'Example Mod 1234 2.0 2026-07-29T00-00Z token.zip'
                                    version = '2.0'
                                    category_id = 1
                                    category_name = 'MAIN'
                                    uploaded_timestamp = 1785283200
                                }
                            )
                        }
                    }
                    default { throw "Unexpected mocked API path: $Path" }
                }
            }

            $plan = @(
                Get-PwProfileModDownloadPlan `
                    -ProfileName 'Stable' `
                    -MissingOnly:$true `
                    -ApiKey 'fixture-key'
            )

            $plan.Count | Should Be 2
            ($plan | Where-Object CatalogKey -eq 'examplemod').Status |
                Should Be 'Ready'
            ($plan | Where-Object CatalogKey -eq 'missingmod').Status |
                Should Be 'NeedsNexusId'
        }
    }

    It 'requests downloads for ready profile mod archive items' {
        InModuleScope PalworldModding {
            Mock Get-PwProfileModDownloadPlan {
                @(
                    [PSCustomObject]@{
                        Status = 'Ready'
                        DisplayName = 'Example Mod'
                        NexusModId = 1234
                        RemoteFileId = 42
                    }
                    [PSCustomObject]@{
                        Status = 'NeedsNexusId'
                        DisplayName = 'Missing ID Mod'
                        NexusModId = $null
                        RemoteFileId = $null
                    }
                )
            }

            Mock Save-PwNexusModUpdate {
                [PSCustomObject]@{
                    Downloaded = $true
                    Path = 'C:\Temp\Example.zip'
                    ModId = 1234
                    FileId = 42
                }
            }

            $result = @(
                Save-PwProfileModDownloads `
                    -ProfileName 'Stable' `
                    -ApiKey 'fixture-key' `
                    -Confirm:$false
            )

            $result.Count | Should Be 2
            Assert-MockCalled Save-PwNexusModUpdate -Times 1 -Scope It
        }
    }
}

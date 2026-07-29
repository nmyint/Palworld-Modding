<#
.SYNOPSIS
    Verifies optional source-provider update checks.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding source-provider updates' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'tracks a mutable GitHub tag by exact asset identity and timestamp' {
        InModuleScope PalworldModding {
            Mock Invoke-PwGitHubApi {
                [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            id = 987
                            name = 'UE4SS-Palworld.zip'
                            updated_at = '2026-07-19T12:00:00Z'
                            browser_download_url = 'https://example.test/ue4ss.zip'
                        },
                        [PSCustomObject]@{
                            id = 988
                            name = 'UE4SS-Palworld_zDEV.zip'
                            updated_at = '2026-07-19T12:00:00Z'
                            browser_download_url = 'https://example.test/dev.zip'
                        }
                    )
                }
            }

            $source = [PSCustomObject]@{
                Key = 'UE4SS'
                DisplayName = 'RE-UE4SS'
                Enabled = $true
                Provider = 'GitHubRelease'
                Repository = 'Okaetsu/RE-UE4SS'
                ReleaseTag = 'experimental-palworld'
                AssetPattern = '^UE4SS-Palworld\.zip$'
                InstalledAssetId = 987
                InstalledAssetUpdatedAt = '2026-07-19T12:00:00Z'
            }
            $result = Get-PwGitHubReleaseSource -Source $source

            $result.Status | Should Be 'Current'
            $result.RemoteFileName | Should Be 'UE4SS-Palworld.zip'
        }
    }

    It 'does not query disabled alternate providers' {
        InModuleScope PalworldModding {
            Mock Invoke-PwGitHubApi { throw 'GitHub should not be called.' }
            Mock Invoke-PwNexusApi {
                param($Path)

                if ($Path -match 'files') {
                    return [PSCustomObject]@{
                        files = @(
                            [PSCustomObject]@{
                                file_id = 3037001
                                file_name = 'PalSchema.zip'
                                version = '260719'
                                category_id = 1
                                category_name = 'MAIN'
                                uploaded_timestamp = 1784419200
                            }
                        )
                    }
                }

                [PSCustomObject]@{
                    name = 'PalSchema'
                    version = '260719'
                    description = (
                        'Source: https://github.com/Okaetsu/PalSchema/releases'
                    )
                }
            }

            $sources = @(
                [PSCustomObject]@{
                    Key = 'PalSchema'
                    DisplayName = 'PalSchema'
                    Enabled = $true
                    Provider = 'NexusMods'
                    NexusModId = 3037
                    InstalledVersion = '260719'
                },
                [PSCustomObject]@{
                    Key = 'PalSchemaGitHub'
                    DisplayName = 'PalSchema GitHub'
                    Enabled = $false
                    Provider = 'GitHubRelease'
                }
            )
            $result = @(
                Get-PwSourceUpdateReport `
                    -ApiKey 'fixture-key' `
                    -Sources $sources
            )

            $result.Count | Should Be 1
            $result[0].Provider | Should Be 'NexusMods'
            $result[0].Status | Should Be 'Current'
            $result[0].DiscoveredGitHubSources.Count | Should Be 1
            Assert-MockCalled Invoke-PwGitHubApi -Times 0 -Scope It
        }
    }
}

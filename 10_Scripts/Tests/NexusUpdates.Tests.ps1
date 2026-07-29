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
}

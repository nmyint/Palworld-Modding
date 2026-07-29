<#
.SYNOPSIS
    Verifies Nexus catalog enrichment and GitHub-source discovery.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding remote catalog metadata' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'uses a reviewed Nexus ID and verifies it against the folder name' {
        InModuleScope PalworldModding {
            Mock Invoke-PwNexusApi {
                [PSCustomObject]@{
                    name = 'Example Mod'
                    version = '2.0'
                    summary = 'Example summary'
                    description = (
                        '<a href="https://github.com/Owner/Example/releases">' +
                            'Source</a>'
                    )
                }
            }
            $catalog = [PSCustomObject]@{
                Mods = @(
                    [PSCustomObject]@{
                        CatalogKey = 'example'
                        InstallNames = @('ExampleMod')
                        Source = 'NexusMods'
                        NexusModIds = @(1234)
                        Versions = @()
                    }
                )
            }
            $result = @(
                Get-PwNexusCatalogMetadataReport `
                    -ApiKey 'fixture-key' `
                    -Catalog $catalog
            )

            $result[0].Status | Should Be 'MetadataFound'
            $result[0].NameMatch | Should Be 'Exact'
            $result[0].GitSources[0].Repository | Should Be 'Owner/Example'
        }
    }

    It 'reports a manual search term instead of guessing without an ID' {
        InModuleScope PalworldModding {
            Mock Invoke-PwNexusApi { throw 'API should not be called.' }
            $catalog = [PSCustomObject]@{
                Mods = @(
                    [PSCustomObject]@{
                        CatalogKey = 'folderonly'
                        InstallNames = @('FolderOnly')
                        Source = 'Manual'
                        NexusModIds = @()
                        Versions = @()
                    }
                )
            }
            $result = @(
                Get-PwNexusCatalogMetadataReport `
                    -ApiKey 'fixture-key' `
                    -Catalog $catalog
            )

            $result[0].Status | Should Be 'NeedsNexusId'
            $result[0].SearchTerm | Should Be 'FolderOnly'
            Assert-MockCalled Invoke-PwNexusApi -Times 0 -Scope It
        }
    }

    It 'normalizes repository and tagged-release links' {
        InModuleScope PalworldModding {
            $sources = @(
                Get-PwGitHubSourcesFromText -Text (
                    'https://github.com/Okaetsu/RE-UE4SS/releases/tag/' +
                        'experimental-palworld'
                )
            )

            $sources[0].Repository | Should Be 'Okaetsu/RE-UE4SS'
            $sources[0].ReleaseTag | Should Be 'experimental-palworld'
        }
    }

    It 'keeps reporting when a hidden Nexus mod is unavailable' {
        InModuleScope PalworldModding {
            Mock Invoke-PwNexusApi {
                [PSCustomObject]@{
                    code = 404
                    message = 'Mod is hidden.'
                }
            }
            $catalog = [PSCustomObject]@{
                Mods = @(
                    [PSCustomObject]@{
                        CatalogKey = 'hidden'
                        InstallNames = @('HiddenMod')
                        Source = 'NexusMods'
                        NexusModIds = @(999)
                        Versions = @()
                    }
                )
            }
            $result = @(
                Get-PwNexusCatalogMetadataReport `
                    -ApiKey 'fixture-key' `
                    -Catalog $catalog
            )

            $result[0].Status | Should Be 'ApiUnavailable'
            $result[0].Error | Should Match 'hidden'
        }
    }
}

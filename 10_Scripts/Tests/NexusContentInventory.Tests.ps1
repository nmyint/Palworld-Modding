<#
.SYNOPSIS
    Verifies lazy Nexus content-preview and local archive inventories.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding lazy Nexus content preview inventory' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'caches raw preview data and classifies a mixed package once' {
        InModuleScope PalworldModding {
            $script:cachePath = Join-Path $TestDrive 'NexusMetadata.json'
            Mock Get-PwNexusMetadataCachePath { $script:cachePath }
            Mock Get-PwCatalogNexusModIds { @(1234) }
            $cache = [PSCustomObject]@{
                SchemaVersion = '1.0'
                GameDomain = 'palworld'
                CreatedAt = '2026-07-31T20:00:00Z'
                UpdatedAt = '2026-07-31T20:00:00Z'
                LastFullRefreshAt = '2026-07-31T20:00:00Z'
                CatalogModIds = @(1234)
                Mods = @(
                    [PSCustomObject]@{
                        NexusModId = 1234
                        RetrievedAt = '2026-07-31T20:00:00Z'
                        Status = 'Ready'
                        LastRefreshError = ''
                        LastRefreshErrorAt = $null
                        Mod = [PSCustomObject]@{ name = 'Example Mod' }
                        Files = [PSCustomObject]@{
                            files = @(
                                [PSCustomObject]@{
                                    file_id = 42
                                    file_name = 'Example-2.0.zip'
                                    version = '2.0'
                                    content_preview_link = (
                                        'https://file-metadata.nexusmods.com/' +
                                            'preview/42.json'
                                    )
                                }
                            )
                        }
                        ContentInventories = @()
                    }
                )
            }
            Write-PwNexusMetadataCache `
                -Cache $cache `
                -Path $script:cachePath
            Mock Invoke-PwNexusApiRequest {
                throw 'Complete Nexus metadata should be served from disk.'
            }
            Mock Invoke-PwNexusContentPreviewRequest {
                [PSCustomObject]@{
                    files = @(
                        'Pal/Binaries/Win64/ue4ss/Mods/Example/Scripts/main.lua'
                        'Pal/Content/Paks/~mods/Example.pak'
                        'Pal/Content/Paks/LogicMods/ExampleLogic.pak'
                    )
                }
            }

            $first = Get-PwNexusFileContentInventory `
                -ModId 1234 `
                -FileId 42 `
                -ApiKey 'fixture-key'
            $second = Get-PwNexusFileContentInventory `
                -ModId 1234 `
                -FileId 42 `
                -ApiKey 'fixture-key'
            $stored = Read-PwNexusMetadataCache -Path $script:cachePath

            $first.Source | Should Be 'NexusContentPreview'
            $first.Authority | Should Be 'Advisory'
            $first.Status | Should Be 'Ready'
            @($first.PackageTypes) -contains 'UE4SSLua' | Should Be $true
            @($first.PackageTypes) -contains 'Pak' | Should Be $true
            @($first.PackageTypes) -contains 'LogicMods' | Should Be $true
            $first.IsMixedPackage | Should Be $true
            $second.FileCount | Should Be 3
            $stored.Mods[0].ContentInventories[0].RawPreview.files.Count |
                Should Be 3
            Assert-MockCalled Invoke-PwNexusContentPreviewRequest `
                -Times 1 `
                -Scope It
            Assert-MockCalled Invoke-PwNexusApiRequest -Times 0 -Scope It
        }
    }
}

Describe 'PalworldModding Nexus content inventory invalidation' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'drops an advisory inventory when its Nexus file metadata changes' {
        InModuleScope PalworldModding {
            $script:cachePath = Join-Path $TestDrive 'NexusMetadata.json'
            Mock Get-PwNexusMetadataCachePath { $script:cachePath }
            Mock Get-PwCatalogNexusModIds { @(1234) }
            $oldFile = [PSCustomObject]@{
                file_id = 42
                file_name = 'Example-2.0.zip'
                version = '2.0'
                content_preview_link = (
                    'https://file-metadata.nexusmods.com/preview/42-v1.json'
                )
            }
            $cache = [PSCustomObject]@{
                SchemaVersion = '1.0'
                GameDomain = 'palworld'
                CreatedAt = '2026-07-31T20:00:00Z'
                UpdatedAt = '2026-07-31T20:00:00Z'
                LastFullRefreshAt = '2026-07-31T20:00:00Z'
                CatalogModIds = @(1234)
                Mods = @(
                    [PSCustomObject]@{
                        NexusModId = 1234
                        RetrievedAt = '2026-07-31T20:00:00Z'
                        Status = 'Ready'
                        LastRefreshError = ''
                        LastRefreshErrorAt = $null
                        Mod = [PSCustomObject]@{ name = 'Example Mod' }
                        Files = [PSCustomObject]@{ files = @($oldFile) }
                        ContentInventories = @(
                            [PSCustomObject]@{
                                FileId = 42
                                FileMetadataFingerprint = (
                                    Get-PwNexusFileMetadataFingerprint `
                                        -File $oldFile
                                )
                                Source = 'NexusContentPreview'
                                Authority = 'Advisory'
                                Status = 'Ready'
                                Paths = @('old/main.lua')
                            }
                        )
                    }
                )
            }
            Write-PwNexusMetadataCache `
                -Cache $cache `
                -Path $script:cachePath
            Mock Invoke-PwNexusApiRequest {
                param($Path, $ApiKey)

                if ($Path -match 'mods/1234/files\.json$') {
                    return [PSCustomObject]@{
                        files = @(
                            [PSCustomObject]@{
                                file_id = 42
                                file_name = 'Example-2.1.zip'
                                version = '2.1'
                                content_preview_link = (
                                    'https://file-metadata.nexusmods.com/' +
                                        'preview/42-v2.json'
                                )
                            }
                        )
                    }
                }

                if ($Path -match 'mods/1234\.json$') {
                    return [PSCustomObject]@{
                        mod_id = 1234
                        name = 'Example Mod'
                        version = '2.1'
                    }
                }

                throw "Unexpected mocked API path: $Path"
            }

            $updated = Update-PwNexusMetadataCache `
                -ApiKey 'fixture-key' `
                -Refresh `
                -Path $script:cachePath

            @($updated.Mods[0].ContentInventories).Count | Should Be 0
            Assert-MockCalled Invoke-PwNexusApiRequest -Times 2 -Scope It
        }
    }
}

Describe 'PalworldModding local archive content authority' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'replaces advisory preview data with one authoritative local inspection' {
        InModuleScope PalworldModding {
            $script:cachePath = Join-Path $TestDrive 'NexusMetadata.json'
            $archivePath = Join-Path $TestDrive 'Example.zip'
            Set-Content -LiteralPath $archivePath -Value 'fixture'
            Mock Get-PwNexusMetadataCachePath { $script:cachePath }
            Mock Get-PwCatalogNexusModIds { @(1234) }
            $cache = [PSCustomObject]@{
                SchemaVersion = '1.0'
                GameDomain = 'palworld'
                CreatedAt = '2026-07-31T20:00:00Z'
                UpdatedAt = '2026-07-31T20:00:00Z'
                LastFullRefreshAt = '2026-07-31T20:00:00Z'
                CatalogModIds = @(1234)
                Mods = @(
                    [PSCustomObject]@{
                        NexusModId = 1234
                        RetrievedAt = '2026-07-31T20:00:00Z'
                        Status = 'Ready'
                        LastRefreshError = ''
                        LastRefreshErrorAt = $null
                        Mod = [PSCustomObject]@{ name = 'Example Mod' }
                        Files = [PSCustomObject]@{
                            files = @(
                                [PSCustomObject]@{
                                    file_id = 42
                                    file_name = 'Example-2.0.zip'
                                    version = '2.0'
                                    content_preview_link = (
                                        'https://file-metadata.nexusmods.com/' +
                                            'preview/42.json'
                                    )
                                }
                            )
                        }
                        ContentInventories = @()
                    }
                )
            }
            Write-PwNexusMetadataCache `
                -Cache $cache `
                -Path $script:cachePath
            Mock Invoke-PwNexusApiRequest {
                throw 'Complete Nexus metadata should be served from disk.'
            }
            Mock Invoke-PwNexusContentPreviewRequest {
                [PSCustomObject]@{
                    files = @('Pal/Content/Paks/~mods/Example.pak')
                }
            }
            Mock Get-PwModArchiveInfo {
                [PSCustomObject]@{
                    ArchiveHash = 'LOCALHASH'
                    Entries = @(
                        [PSCustomObject]@{
                            DeploymentRelativePath = (
                                'Pal\Binaries\Win64\ue4ss\Mods\Example\' +
                                    'Scripts\main.lua'
                            )
                            ArchivePath = 'Example/Scripts/main.lua'
                        }
                        [PSCustomObject]@{
                            DeploymentRelativePath = (
                                'Pal\Content\Paks\LogicMods\Example.pak'
                            )
                            ArchivePath = 'Example.pak'
                        }
                    )
                }
            }

            $remote = Get-PwNexusFileContentInventory `
                -ModId 1234 `
                -FileId 42 `
                -ApiKey 'fixture-key'
            $local = Get-PwNexusFileContentInventory `
                -ModId 1234 `
                -FileId 42 `
                -ApiKey 'fixture-key' `
                -ArchivePath $archivePath `
                -ArchiveHash 'LOCALHASH'
            $again = Get-PwNexusFileContentInventory `
                -ModId 1234 `
                -FileId 42 `
                -ApiKey 'fixture-key' `
                -ArchivePath $archivePath `
                -ArchiveHash 'LOCALHASH'

            $remote.Source | Should Be 'NexusContentPreview'
            $local.Source | Should Be 'LocalArchiveInspection'
            $local.Authority | Should Be 'Authoritative'
            @($local.PackageTypes) -contains 'UE4SSLua' | Should Be $true
            @($local.PackageTypes) -contains 'LogicMods' | Should Be $true
            $local.IsMixedPackage | Should Be $true
            $again.ArchiveHash | Should Be 'LOCALHASH'
            Assert-MockCalled Get-PwModArchiveInfo -Times 1 -Scope It
        }
    }
}

Describe 'PalworldModding update report content enrichment' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'adds cached package classification to an actionable update row' {
        InModuleScope PalworldModding {
            $script:PwGetModUpdateReportCore = {
                [PSCustomObject]@{
                    Name = 'Example Mod'
                    NexusModId = 1234
                    RemoteFileId = 42
                    Status = 'UpdateAvailable'
                }
            }
            Mock Get-PwNexusArchiveMetadata { @() }
            Mock Get-PwNexusFileContentInventory {
                [PSCustomObject]@{
                    Status = 'Ready'
                    Source = 'NexusContentPreview'
                    PackageTypes = @('UE4SSLua', 'Pak')
                    DetectedRoots = @(
                        'Pal/Binaries/Win64/ue4ss/Mods/Example'
                        'Pal/Content/Paks/~mods'
                    )
                    FileCount = 8
                    IsMixedPackage = $true
                }
            }

            $row = Get-PwModUpdateReport `
                -ApiKey 'fixture-key' |
                Select-Object -First 1

            $row.RemoteContentInventoryStatus | Should Be 'Ready'
            $row.RemoteContentInventorySource | Should Be 'NexusContentPreview'
            @($row.RemotePackageTypes) -contains 'UE4SSLua' | Should Be $true
            @($row.RemotePackageTypes) -contains 'Pak' | Should Be $true
            $row.RemoteContentFileCount | Should Be 8
            $row.RemoteIsMixedPackage | Should Be $true
            Assert-MockCalled Get-PwNexusFileContentInventory -Times 1 -Scope It
        }
    }
}

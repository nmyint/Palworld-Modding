<#
.SYNOPSIS
    Verifies fail-closed Nexus behavior, persistent caching, and menu safety.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding explicit-ID Nexus preview safety' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'preserves non-mutating WhatIf for explicit-ID callers outside the menu' {
        InModuleScope PalworldModding {
            Mock Get-PSCallStack {
                @([PSCustomObject]@{ FunctionName = 'Invoke-ExternalCaller' })
            }
            Mock Get-PwNexusApiIdentity {
                [PSCustomObject]@{ is_premium = $true }
            }
            Mock Update-PwNexusMetadataCache {
                [PSCustomObject]@{ Mods = @() }
            }
            Mock Invoke-PwNexusApi {
                param($Path)

                if ($Path -like '*/download_link.json') {
                    return @(
                        [PSCustomObject]@{
                            URI = 'https://example.invalid/Example-2.0.zip'
                        }
                    )
                }

                if ($Path -like '*/files/42.json') {
                    return [PSCustomObject]@{
                        file_name = 'Example-2.0.zip'
                        version = '2.0'
                    }
                }

                [PSCustomObject]@{ name = 'Example Mod' }
            }
            Mock Save-PwRemoteFile {
                throw 'WhatIf must not download a file.'
            }
            Mock Get-PwModArchiveInfo {
                throw 'WhatIf must not inspect a downloaded file.'
            }

            $result = Save-PwNexusModUpdate `
                -ModId 1234 `
                -FileId 42 `
                -ApiKey 'fixture-key' `
                -Destination $TestDrive `
                -WhatIf

            $result.Downloaded | Should Be $false
            $result.ModId | Should Be 1234
            $result.FileId | Should Be 42
            Assert-MockCalled Save-PwRemoteFile -Times 0 -Scope It
            Assert-MockCalled Get-PwModArchiveInfo -Times 0 -Scope It
        }
    }
}

Describe 'PalworldModding refreshed-report Nexus menu safety' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'blocks direct menu download when the refreshed report returns no row' {
        InModuleScope PalworldModding {
            Mock Get-PSCallStack {
                @([PSCustomObject]@{ FunctionName = 'Start-PwWorkshop' })
            }
            Mock Update-PwNexusMetadataCache {
                [PSCustomObject]@{ Mods = @() }
            }
            Mock Get-PwModUpdateReport { @() }
            Mock Save-PwNexusModUpdateCore {
                throw 'The low-level downloader must not run.'
            }
            Mock Save-PwModUpdateFromReport {
                throw 'The guarded downloader must not run without a row.'
            }
            $message = ''

            try {
                Save-PwNexusModUpdate `
                    -ModId 1234 `
                    -FileId 42 `
                    -ApiKey 'fixture-key' `
                    -Destination $TestDrive `
                    -Confirm:$false
            }
            catch {
                $message = $_.Exception.Message
            }

            $message | Should Match 'returned no row'
            $message | Should Match 'blocked'
            Assert-MockCalled Save-PwNexusModUpdateCore -Times 0 -Scope It
            Assert-MockCalled Save-PwModUpdateFromReport -Times 0 -Scope It
        }
    }
}

Describe 'PalworldModding full Nexus catalog snapshot' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'stores complete raw mod and file-list responses for every catalog ID' {
        InModuleScope PalworldModding {
            $cachePath = Join-Path $TestDrive 'NexusMetadata.json'
            Mock Get-PwCatalogNexusModIds { @(1234, 5678) }
            Mock Invoke-PwNexusApiRequest {
                param($Path, $ApiKey)

                if ($Path -match 'mods/1234/files\.json$') {
                    return [PSCustomObject]@{
                        files = @(
                            [PSCustomObject]@{
                                file_id = 42
                                file_name = 'Example-2.0.zip'
                                version = '2.0'
                                changelog_html = '<p>Full file metadata</p>'
                            }
                        )
                        file_updates = @(
                            [PSCustomObject]@{ old_file_id = 41; new_file_id = 42 }
                        )
                    }
                }

                if ($Path -match 'mods/5678/files\.json$') {
                    return [PSCustomObject]@{
                        files = @(
                            [PSCustomObject]@{
                                file_id = 84
                                file_name = 'Second-4.0.7z'
                                version = '4.0'
                                size_kb = 2048
                            }
                        )
                    }
                }

                if ($Path -match 'mods/1234\.json$') {
                    return [PSCustomObject]@{
                        mod_id = 1234
                        name = 'Example Mod'
                        version = '2.0'
                        author = 'Example Author'
                        description = '<p>Complete description</p>'
                        endorsement_count = 25
                    }
                }

                if ($Path -match 'mods/5678\.json$') {
                    return [PSCustomObject]@{
                        mod_id = 5678
                        name = 'Second Mod'
                        version = '4.0'
                        contains_adult_content = $false
                    }
                }

                throw "Unexpected mocked API path: $Path"
            }

            $cache = Update-PwNexusMetadataCache `
                -ApiKey 'fixture-key' `
                -Refresh `
                -Path $cachePath

            @($cache.Mods).Count | Should Be 2
            $cache.Mods[0].Mod.author | Should Be 'Example Author'
            $cache.Mods[0].Mod.endorsement_count | Should Be 25
            $cache.Mods[0].Files.file_updates[0].new_file_id | Should Be 42
            $cache.Mods[0].Files.files[0].changelog_html |
                Should Match 'Full file metadata'
            $cache.Mods[1].Files.files[0].size_kb | Should Be 2048
            Test-Path -LiteralPath $cachePath | Should Be $true
            Assert-MockCalled Invoke-PwNexusApiRequest -Times 4 -Scope It
        }
    }
}

Describe 'PalworldModding persistent Nexus snapshot reuse' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'serves mod and file metadata from disk without another API request' {
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
                        Mod = [PSCustomObject]@{
                            name = 'Example Mod'
                            author = 'Cached Author'
                        }
                        Files = [PSCustomObject]@{
                            files = @(
                                [PSCustomObject]@{
                                    file_id = 42
                                    file_name = 'Example-2.0.zip'
                                }
                            )
                        }
                    }
                )
            }
            Write-PwNexusMetadataCache `
                -Cache $cache `
                -Path $script:cachePath
            Mock Invoke-PwNexusApiRequest {
                throw 'The API should not be called for a complete cache.'
            }

            $mod = Invoke-PwNexusApi `
                -Path 'games/palworld/mods/1234.json' `
                -ApiKey 'fixture-key'
            $files = Invoke-PwNexusApi `
                -Path 'games/palworld/mods/1234/files.json' `
                -ApiKey 'fixture-key'

            $mod.author | Should Be 'Cached Author'
            $files.files[0].file_id | Should Be 42
            Assert-MockCalled Invoke-PwNexusApiRequest -Times 0 -Scope It
        }
    }
}

Describe 'PalworldModding catalog cache coverage changes' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'fetches only a newly added catalog ID when the existing snapshot is valid' {
        InModuleScope PalworldModding {
            $script:cachePath = Join-Path $TestDrive 'NexusMetadata.json'
            Mock Get-PwNexusMetadataCachePath { $script:cachePath }
            Mock Get-PwCatalogNexusModIds { @(1234, 5678) }
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
                        Files = [PSCustomObject]@{ files = @() }
                    }
                )
            }
            Write-PwNexusMetadataCache `
                -Cache $cache `
                -Path $script:cachePath
            Mock Invoke-PwNexusApiRequest {
                param($Path, $ApiKey)

                if ($Path -match 'mods/5678/files\.json$') {
                    return [PSCustomObject]@{ files = @() }
                }

                if ($Path -match 'mods/5678\.json$') {
                    return [PSCustomObject]@{ name = 'New Catalog Mod' }
                }

                throw "Unexpected API path: $Path"
            }

            $mod = Invoke-PwNexusApi `
                -Path 'games/palworld/mods/1234.json' `
                -ApiKey 'fixture-key'
            $updated = Read-PwNexusMetadataCache -Path $script:cachePath

            $mod.name | Should Be 'Example Mod'
            @($updated.Mods).Count | Should Be 2
            Assert-MockCalled Invoke-PwNexusApiRequest -Times 2 -Scope It
        }
    }
}

Describe 'PalworldModding cached exact Nexus file metadata' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'resolves an exact file from the cached full file-list response' {
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
                                    description = 'Cached exact file metadata'
                                }
                            )
                        }
                    }
                )
            }
            Write-PwNexusMetadataCache `
                -Cache $cache `
                -Path $script:cachePath
            Mock Invoke-PwNexusApiRequest {
                throw 'The exact file should come from the cached file list.'
            }

            $file = Invoke-PwNexusApi `
                -Path 'games/palworld/mods/1234/files/42.json' `
                -ApiKey 'fixture-key'

            $file.file_name | Should Be 'Example-2.0.zip'
            $file.description | Should Match 'Cached exact file metadata'
            Assert-MockCalled Invoke-PwNexusApiRequest -Times 0 -Scope It
        }
    }
}

Describe 'PalworldModding transient Nexus download links' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'always requests direct download-link responses live' {
        InModuleScope PalworldModding {
            Mock Invoke-PwNexusApiRequest {
                [PSCustomObject]@{
                    URI = 'https://example.invalid/Example-2.0.zip'
                }
            }
            $path = (
                'games/palworld/mods/1234/files/42/download_link.json'
            )

            $null = Invoke-PwNexusApi -Path $path -ApiKey 'fixture-key'
            $null = Invoke-PwNexusApi -Path $path -ApiKey 'fixture-key'

            Assert-MockCalled Invoke-PwNexusApiRequest -Times 2 -Scope It
        }
    }
}

Describe 'PalworldModding GitHub metadata session cache' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'reuses release metadata until its provider cache is cleared' {
        InModuleScope PalworldModding {
            Clear-PwGitHubMetadataCache
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ tag_name = 'experimental-palworld' }
            }
            $path = (
                'repos/Okaetsu/RE-UE4SS/releases/tags/' +
                    'experimental-palworld'
            )

            $null = Invoke-PwGitHubApi -Path $path
            $null = Invoke-PwGitHubApi -Path $path
            Clear-PwGitHubMetadataCache
            $null = Invoke-PwGitHubApi -Path $path

            Assert-MockCalled Invoke-RestMethod -Times 2 -Scope It
        }
    }
}

Describe 'PalworldModding option 4 cache timestamp and back navigation' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'shows the persistent cache timestamp and maps B to return' {
        InModuleScope PalworldModding {
            $script:capturedPrompt = ''
            $script:capturedTitle = ''
            Mock Get-PwNexusMetadataCacheInfo {
                [PSCustomObject]@{
                    LastFullRefreshAt = '2026-07-31T20:00:00Z'
                    UpdatedAt = '2026-07-31T20:00:00Z'
                    ReadyModCount = 30
                    CatalogModCount = 30
                }
            }
            Mock Show-PwWorkshopPagedTable {
                param($Title)

                $script:capturedTitle = $Title
                [PSCustomObject]@{ Page = 1; PageCount = 1 }
            }
            Mock Write-Host {}
            Mock Read-Host {
                param($Prompt)

                $script:capturedPrompt = $Prompt
                'B'
            }

            $selection = Read-PwWorkshopPagedTable `
                -Title 'Mod and Tool Updates' `
                -Rows @() `
                -Properties @('Name') `
                -Prompt (
                    'Nexus mod ID, [U] record UE4SS baseline, ' +
                        'Enter to return, or Q to quit'
                )

            $selection | Should Be ''
            $script:capturedPrompt | Should Match '\[R\] Refresh'
            $script:capturedPrompt | Should Match '\[B\] Back'
            $script:capturedTitle | Should Match '2026-07-31 20:00:00 UTC'
            $script:capturedTitle | Should Match '30/30 mods'
        }
    }
}

Describe 'PalworldModding option 4 explicit full refresh' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'refreshes the whole Nexus snapshot and GitHub source metadata' {
        InModuleScope PalworldModding {
            Mock Get-PwNexusMetadataCacheInfo {
                [PSCustomObject]@{
                    LastFullRefreshAt = '2026-07-31T20:00:00Z'
                    UpdatedAt = '2026-07-31T20:00:00Z'
                    ReadyModCount = 30
                    CatalogModCount = 30
                }
            }
            Mock Update-PwNexusMetadataCache {
                [PSCustomObject]@{ Mods = @() }
            }
            Mock Clear-PwGitHubMetadataCache {}
            Mock Show-PwWorkshopPagedTable {
                [PSCustomObject]@{ Page = 1; PageCount = 1 }
            }
            Mock Write-Host {}
            Mock Read-Host { 'R' }

            $selection = Read-PwWorkshopPagedTable `
                -Title 'Mod and Tool Updates' `
                -Rows @() `
                -Properties @('Name') `
                -Prompt (
                    'Nexus mod ID, [U] record UE4SS baseline, ' +
                        'Enter to return, or Q to quit'
                )

            $selection | Should Be 'R'
            Assert-MockCalled Update-PwNexusMetadataCache `
                -Times 1 `
                -Scope It `
                -ParameterFilter { $Refresh }
            Assert-MockCalled Clear-PwGitHubMetadataCache -Times 1 -Scope It
        }
    }
}

Describe 'PalworldModding catalog metadata explicit refresh UX' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'refreshes and redraws the remote metadata screen in place' {
        InModuleScope PalworldModding {
            $script:selections = @('R', 'B')
            $script:selectionIndex = 0
            Mock Get-PwNexusMetadataCacheInfo {
                [PSCustomObject]@{
                    LastFullRefreshAt = '2026-07-31T20:00:00Z'
                    UpdatedAt = '2026-07-31T20:00:00Z'
                    ReadyModCount = 30
                    CatalogModCount = 30
                }
            }
            Mock Update-PwNexusMetadataCache {
                [PSCustomObject]@{ Mods = @() }
            }
            Mock Get-PwNexusCatalogMetadataReport {
                @([PSCustomObject]@{ CatalogKey = 'example' })
            }
            Mock Show-PwWorkshopPagedTable {
                [PSCustomObject]@{ Page = 1; PageCount = 1 }
            }
            Mock Write-Host {}
            Mock Read-Host {
                $selection = $script:selections[$script:selectionIndex]
                $script:selectionIndex++
                $selection
            }

            $selection = Read-PwWorkshopPagedTable `
                -Title 'Remote Catalog Metadata' `
                -Rows @() `
                -Properties @('CatalogKey') `
                -Prompt (
                    '[A] Store metadata, [V] Verify review item, ' +
                        '[B] Back, or Q to quit'
                )

            $selection | Should Be 'B'
            Assert-MockCalled Update-PwNexusMetadataCache `
                -Times 1 `
                -Scope It `
                -ParameterFilter { $Refresh }
            Assert-MockCalled Get-PwNexusCatalogMetadataReport -Times 1 -Scope It
        }
    }
}

Describe 'PalworldModding manual Nexus download handoff' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'opens the files page while preserving the archive intake boundary' {
        InModuleScope PalworldModding {
            Mock Get-PwPaths {
                [PSCustomObject]@{ Archives = $TestDrive }
            }
            Mock Start-Process {}
            Mock Write-Host {}

            $result = Open-PwNexusModPage `
                -ModId 1234 `
                -Launch `
                -Confirm:$false

            $result | Should Be (
                'https://www.nexusmods.com/palworld/mods/1234?tab=files'
            )
            Assert-MockCalled Start-Process -Times 1 -Scope It
        }
    }
}

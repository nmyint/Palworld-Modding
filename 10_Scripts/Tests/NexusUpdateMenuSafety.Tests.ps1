<#
.SYNOPSIS
    Verifies fail-closed Nexus behavior, remote caching, and update-menu safety.
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
                [PSCustomObject]@{
                    is_premium = $true
                }
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

                [PSCustomObject]@{
                    name = 'Example Mod'
                }
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
            Mock Get-PwModUpdateReport {
                @()
            }
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

Describe 'PalworldModding Nexus metadata session cache' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'reuses one successful metadata response during the cache window' {
        InModuleScope PalworldModding {
            Clear-PwRemoteMetadataCache
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    name = 'Example Mod'
                }
            }

            $first = Invoke-PwNexusApi `
                -Path 'games/palworld/mods/1234.json' `
                -ApiKey 'fixture-key'
            $second = Invoke-PwNexusApi `
                -Path 'games/palworld/mods/1234.json' `
                -ApiKey 'fixture-key'

            $first.name | Should Be 'Example Mod'
            $second.name | Should Be 'Example Mod'
            Assert-MockCalled Invoke-RestMethod -Times 1 -Scope It
        }
    }
}

Describe 'PalworldModding transient Nexus download links' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'never caches direct download-link responses' {
        InModuleScope PalworldModding {
            Clear-PwRemoteMetadataCache
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    URI = 'https://example.invalid/Example-2.0.zip'
                }
            }
            $path = (
                'games/palworld/mods/1234/files/42/download_link.json'
            )

            $null = Invoke-PwNexusApi -Path $path -ApiKey 'fixture-key'
            $null = Invoke-PwNexusApi -Path $path -ApiKey 'fixture-key'

            Assert-MockCalled Invoke-RestMethod -Times 2 -Scope It
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
            Clear-PwRemoteMetadataCache
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    tag_name = 'experimental-palworld'
                }
            }
            $path = (
                'repos/Okaetsu/RE-UE4SS/releases/tags/' +
                    'experimental-palworld'
            )

            $null = Invoke-PwGitHubApi -Path $path
            $null = Invoke-PwGitHubApi -Path $path
            Clear-PwRemoteMetadataCache -Provider GitHub
            $null = Invoke-PwGitHubApi -Path $path

            Assert-MockCalled Invoke-RestMethod -Times 2 -Scope It
        }
    }
}

Describe 'PalworldModding option 4 back navigation' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'shows Back and Refresh and maps B to the existing return behavior' {
        InModuleScope PalworldModding {
            $script:capturedPrompt = ''
            Mock Show-PwWorkshopPagedTable {
                [PSCustomObject]@{
                    Page = 1
                    PageCount = 1
                }
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
        }
    }
}

Describe 'PalworldModding option 4 explicit refresh' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'clears cached provider responses before the menu reruns its reports' {
        InModuleScope PalworldModding {
            $script:PwRemoteMetadataCache['NexusMods|fixture|example'] = (
                [PSCustomObject]@{
                    Provider = 'NexusMods'
                    Path = 'example'
                    RetrievedAt = (Get-Date).ToUniversalTime()
                    Value = [PSCustomObject]@{ name = 'Example' }
                }
            )
            Mock Show-PwWorkshopPagedTable {
                [PSCustomObject]@{
                    Page = 1
                    PageCount = 1
                }
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
            $script:PwRemoteMetadataCache.Count | Should Be 0
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
                [PSCustomObject]@{
                    Archives = $TestDrive
                }
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

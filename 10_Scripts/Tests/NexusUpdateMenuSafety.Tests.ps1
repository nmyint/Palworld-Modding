<#
.SYNOPSIS
    Verifies fail-closed behavior for refreshed Nexus menu reports.
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

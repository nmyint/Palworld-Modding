<#
.SYNOPSIS
    Verifies guarded Nexus download behavior when invoked by the workshop menu.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding Nexus update menu wiring' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'previews the exact actionable menu update without downloading' {
        InModuleScope PalworldModding {
            Mock Get-PSCallStack {
                @([PSCustomObject]@{ FunctionName = 'Start-PwWorkshop' })
            }
            Mock Get-PwModUpdateReport {
                @(
                    [PSCustomObject]@{
                        Name = 'Example Mod'
                        NexusModId = 1234
                        LocalVersion = '1.0'
                        RemoteVersion = '2.0'
                        RemoteFileId = 42
                        RemoteFileName = 'Example-2.0.zip'
                        LocalVariant = 'SinglePlayer'
                        RemoteVariant = 'SinglePlayer'
                        Status = 'UpdateAvailable'
                    }
                )
            }
            Mock Save-PwModUpdateFromReport {
                throw 'The guarded downloader should not run during WhatIf.'
            }

            $result = Save-PwNexusModUpdate `
                -ModId 1234 `
                -FileId 42 `
                -ApiKey 'fixture-key' `
                -Destination $TestDrive `
                -WhatIf

            $result.Downloaded | Should Be $false
            $result.NexusModId | Should Be 1234
            $result.FileId | Should Be 42
            $result.RemoteVersion | Should Be '2.0'
            Assert-MockCalled Save-PwModUpdateFromReport -Times 0 -Scope It
        }
    }

    It 'routes an approved actionable menu update through the report command' {
        InModuleScope PalworldModding {
            Mock Get-PSCallStack {
                @([PSCustomObject]@{ FunctionName = 'Start-PwWorkshop' })
            }
            Mock Get-PwModUpdateReport {
                @(
                    [PSCustomObject]@{
                        Name = 'Example Mod'
                        NexusModId = 1234
                        LocalVersion = '1.0'
                        RemoteVersion = '2.0'
                        RemoteFileId = 42
                        RemoteFileName = 'Example-2.0.zip'
                        LocalVariant = ''
                        RemoteVariant = ''
                        Status = 'UpdateAvailable'
                    }
                )
            }
            Mock Save-PwModUpdateFromReport {
                [PSCustomObject]@{
                    Name = 'Example Mod'
                    NexusModId = 1234
                    FileId = 42
                    LocalVersion = '1.0'
                    RemoteVersion = '2.0'
                    RemoteFileName = 'Example-2.0.zip'
                    Downloaded = $true
                    Path = 'C:\Archives\Example-2.0.zip'
                    Hash = 'ABC123'
                    NextStep = 'Inspect and import the archive through menu option 2.'
                }
            }

            $result = Save-PwNexusModUpdate `
                -ModId 1234 `
                -FileId 42 `
                -ApiKey 'fixture-key' `
                -Destination $TestDrive `
                -Confirm:$false

            $result.Downloaded | Should Be $true
            $result.Path | Should Be 'C:\Archives\Example-2.0.zip'
            $result.Hash | Should Be 'ABC123'
            Assert-MockCalled Save-PwModUpdateFromReport `
                -Times 1 `
                -Scope It `
                -ParameterFilter {
                    $Update.NexusModId -eq 1234 -and
                    $Update.RemoteFileId -eq 42 -and
                    $ApiKey -eq 'fixture-key' -and
                    $Destination -eq $TestDrive
                }
        }
    }

    It 'refuses a non-actionable menu update before download' {
        InModuleScope PalworldModding {
            Mock Get-PSCallStack {
                @([PSCustomObject]@{ FunctionName = 'Start-PwWorkshop' })
            }
            Mock Get-PwModUpdateReport {
                @(
                    [PSCustomObject]@{
                        Name = 'Example Mod'
                        NexusModId = 1234
                        LocalVersion = '2.0'
                        RemoteVersion = '2.0'
                        RemoteFileId = 42
                        RemoteFileName = 'Example-2.0.zip'
                        Status = 'Current'
                    }
                )
            }
            Mock Save-PwModUpdateFromReport {
                throw 'The guarded downloader should not run.'
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
            Assert-MockCalled Save-PwModUpdateFromReport -Times 0 -Scope It
        }
    }

    It 'refuses a stale menu file ID and requires a refreshed report' {
        InModuleScope PalworldModding {
            Mock Get-PSCallStack {
                @([PSCustomObject]@{ FunctionName = 'Start-PwWorkshop' })
            }
            Mock Get-PwModUpdateReport {
                @(
                    [PSCustomObject]@{
                        Name = 'Example Mod'
                        NexusModId = 1234
                        LocalVersion = '1.0'
                        RemoteVersion = '2.1'
                        RemoteFileId = 84
                        RemoteFileName = 'Example-2.1.zip'
                        Status = 'UpdateAvailable'
                    }
                )
            }
            Mock Save-PwModUpdateFromReport {
                throw 'The guarded downloader should not run.'
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

            $message | Should Match 'stale'
            $message | Should Match '84'
            Assert-MockCalled Save-PwModUpdateFromReport -Times 0 -Scope It
        }
    }

    It 'preserves low-level explicit-ID behavior outside the workshop menu' {
        InModuleScope PalworldModding {
            Mock Get-PSCallStack {
                @([PSCustomObject]@{ FunctionName = 'Invoke-ExternalCaller' })
            }
            Mock Save-PwNexusModUpdateCore {
                [PSCustomObject]@{
                    Downloaded = $true
                    Path = 'C:\Archives\Example-2.0.zip'
                    ModId = 1234
                    FileId = 42
                    Version = '2.0'
                    Hash = 'ABC123'
                }
            }
            Mock Get-PwModUpdateReport {
                throw 'The update report should not be requested.'
            }

            $result = Save-PwNexusModUpdate `
                -ModId 1234 `
                -FileId 42 `
                -ApiKey 'fixture-key' `
                -Destination $TestDrive `
                -Confirm:$false

            $result.Downloaded | Should Be $true
            Assert-MockCalled Save-PwNexusModUpdateCore -Times 1 -Scope It
            Assert-MockCalled Get-PwModUpdateReport -Times 0 -Scope It
        }
    }
}

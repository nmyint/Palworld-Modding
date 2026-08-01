<#
.SYNOPSIS
    Verifies guarded downloads from Nexus update-report rows.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding guarded Nexus update downloads' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'refuses a report row that is already current' {
        InModuleScope PalworldModding {
            Mock Save-PwNexusModUpdateCore {
                throw 'The downloader should not be called.'
            }

            $update = [PSCustomObject]@{
                Name = 'Example Mod'
                NexusModId = 1234
                LocalVersion = '2.0'
                RemoteVersion = '2.0'
                RemoteFileId = 42
                RemoteFileName = 'Example-2.0.zip'
                Status = 'Current'
            }
            $threw = $false

            try {
                Save-PwModUpdateFromReport `
                    -Update $update `
                    -ApiKey 'fixture-key' `
                    -Destination $TestDrive `
                    -Confirm:$false
            }
            catch {
                $threw = $true
            }

            $threw | Should Be $true
            Assert-MockCalled Save-PwNexusModUpdateCore -Times 0 -Scope It
        }
    }

    It 'refuses an update row without a remote file ID' {
        InModuleScope PalworldModding {
            Mock Save-PwNexusModUpdateCore {
                throw 'The downloader should not be called.'
            }

            $update = [PSCustomObject]@{
                Name = 'Example Mod'
                NexusModId = 1234
                LocalVersion = '1.0'
                RemoteVersion = '2.0'
                RemoteFileId = 0
                RemoteFileName = ''
                Status = 'UpdateAvailable'
            }
            $threw = $false

            try {
                Save-PwModUpdateFromReport `
                    -Update $update `
                    -ApiKey 'fixture-key' `
                    -Destination $TestDrive `
                    -Confirm:$false
            }
            catch {
                $threw = $true
            }

            $threw | Should Be $true
            Assert-MockCalled Save-PwNexusModUpdateCore -Times 0 -Scope It
        }
    }

    It 'downloads the exact file selected by an actionable report row' {
        InModuleScope PalworldModding {
            Mock Save-PwNexusModUpdateCore {
                [PSCustomObject]@{
                    Downloaded = $true
                    Path = Join-Path $TestDrive 'Example Mod 1234 2.0.zip'
                    ModId = 1234
                    FileId = 42
                    Version = '2.0'
                    Hash = 'ABC123'
                }
            }

            $update = [PSCustomObject]@{
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
            $result = Save-PwModUpdateFromReport `
                -Update $update `
                -ApiKey 'fixture-key' `
                -Destination $TestDrive `
                -Confirm:$false

            $result.Downloaded | Should Be $true
            $result.NexusModId | Should Be 1234
            $result.FileId | Should Be 42
            $result.RemoteFileName | Should Be 'Example-2.0.zip'
            $result.Hash | Should Be 'ABC123'
            $result.NextStep | Should Match 'menu option 2'
            Assert-MockCalled Save-PwNexusModUpdateCore `
                -Times 1 `
                -Scope It `
                -ParameterFilter {
                    $ModId -eq 1234 -and
                    $FileId -eq 42 -and
                    $ApiKey -eq 'fixture-key' -and
                    $Destination -eq $TestDrive
                }
        }
    }

    It 'supports preview without calling the downloader' {
        InModuleScope PalworldModding {
            Mock Save-PwNexusModUpdateCore {
                throw 'The downloader should not be called.'
            }

            $update = [PSCustomObject]@{
                Name = 'Example Mod'
                NexusModId = 1234
                LocalVersion = '1.0'
                RemoteVersion = '2.0'
                RemoteFileId = 42
                RemoteFileName = 'Example-2.0.zip'
                Status = 'UpdateAvailable'
            }
            $result = Save-PwModUpdateFromReport `
                -Update $update `
                -ApiKey 'fixture-key' `
                -Destination $TestDrive `
                -WhatIf

            $result.Downloaded | Should Be $false
            $result.FileId | Should Be 42
            Assert-MockCalled Save-PwNexusModUpdateCore -Times 0 -Scope It
        }
    }

    It 'returns one preview result for every actionable pipeline row' {
        InModuleScope PalworldModding {
            Mock Save-PwNexusModUpdateCore {
                throw 'The downloader should not be called.'
            }

            $updates = @(
                [PSCustomObject]@{
                    Name = 'Example One'
                    NexusModId = 1234
                    LocalVersion = '1.0'
                    RemoteVersion = '2.0'
                    RemoteFileId = 42
                    RemoteFileName = 'Example-One-2.0.zip'
                    Status = 'UpdateAvailable'
                }
                [PSCustomObject]@{
                    Name = 'Example Two'
                    NexusModId = 5678
                    LocalVersion = '3.0'
                    RemoteVersion = '4.0'
                    RemoteFileId = 84
                    RemoteFileName = 'Example-Two-4.0.7z'
                    Status = 'UpdateAvailable'
                }
            )
            $results = @(
                $updates |
                    Save-PwModUpdateFromReport `
                        -ApiKey 'fixture-key' `
                        -Destination $TestDrive `
                        -WhatIf
            )

            $results.Count | Should Be 2
            $results[0].FileId | Should Be 42
            $results[1].FileId | Should Be 84
            Assert-MockCalled Save-PwNexusModUpdateCore -Times 0 -Scope It
        }
    }
}

<#
.SYNOPSIS
    Exercises the actual Start-PwWorkshop option 4 interaction path safely.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding option 4 interaction flow' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'routes a direct option 4 selection through the guarded report command' {
        InModuleScope PalworldModding {
            $script:updateFixture = [PSCustomObject]@{
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
            $script:mainSelections = @('4', 'Q')
            $script:mainSelectionIndex = 0
            $script:updateSelections = @('1234', '')
            $script:updateSelectionIndex = 0

            Mock Initialize-PwWorkshop {}
            Mock Get-PwWorkshopTerminalSize {
                [PSCustomObject]@{
                    Width = 80
                    Height = 24
                }
            }
            Mock Show-PwWorkshopMenu {}
            Mock Read-PwWorkshopMenuSelection {
                $selection = $script:mainSelections[
                    $script:mainSelectionIndex
                ]
                $script:mainSelectionIndex++
                $selection
            }
            Mock Invoke-PwWorkshopMenuAction {
                param($Action)

                switch ($Action) {
                    'Updates' {
                        @($script:updateFixture)
                    }
                    'SourceUpdates' {
                        @()
                    }
                    default {
                        throw "Unexpected menu action in fixture: $Action"
                    }
                }
            }
            Mock Read-PwWorkshopPagedTable {
                $selection = $script:updateSelections[
                    $script:updateSelectionIndex
                ]
                $script:updateSelectionIndex++
                $selection
            }
            Mock Read-Host {
                'D'
            }
            Mock Get-PwModUpdateReport {
                @($script:updateFixture)
            }
            Mock Save-PwModUpdateFromReport {
                [PSCustomObject]@{
                    Name = $Update.Name
                    NexusModId = $Update.NexusModId
                    FileId = $Update.RemoteFileId
                    LocalVersion = $Update.LocalVersion
                    RemoteVersion = $Update.RemoteVersion
                    RemoteFileName = $Update.RemoteFileName
                    Downloaded = $true
                    Path = 'C:\Archives\Example-2.0.zip'
                    Hash = 'ABC123'
                    NextStep = (
                        'Inspect and import the archive through menu option 2.'
                    )
                }
            }
            Mock Open-PwNexusModPage {
                throw 'The manual browser path should not run in direct mode.'
            }
            Mock Write-Host {}

            $previousConfirmPreference = $ConfirmPreference
            $ConfirmPreference = 'None'

            try {
                Start-PwWorkshop -NoClear
            }
            finally {
                $ConfirmPreference = $previousConfirmPreference
            }

            Assert-MockCalled Save-PwModUpdateFromReport `
                -Times 1 `
                -Scope It `
                -ParameterFilter {
                    $Update.NexusModId -eq 1234 -and
                    $Update.RemoteFileId -eq 42
                }
            Assert-MockCalled Open-PwNexusModPage -Times 0 -Scope It
        }
    }

    It 'keeps the option 4 manual browser path available' {
        InModuleScope PalworldModding {
            $script:updateFixture = [PSCustomObject]@{
                Name = 'Example Mod'
                NexusModId = 1234
                LocalVersion = '1.0'
                RemoteVersion = '2.0'
                RemoteFileId = 42
                RemoteFileName = 'Example-2.0.zip'
                Status = 'UpdateAvailable'
            }
            $script:mainSelections = @('4', 'Q')
            $script:mainSelectionIndex = 0
            $script:updateSelections = @('1234', '')
            $script:updateSelectionIndex = 0

            Mock Initialize-PwWorkshop {}
            Mock Get-PwWorkshopTerminalSize {
                [PSCustomObject]@{
                    Width = 80
                    Height = 24
                }
            }
            Mock Show-PwWorkshopMenu {}
            Mock Read-PwWorkshopMenuSelection {
                $selection = $script:mainSelections[
                    $script:mainSelectionIndex
                ]
                $script:mainSelectionIndex++
                $selection
            }
            Mock Invoke-PwWorkshopMenuAction {
                param($Action)

                switch ($Action) {
                    'Updates' {
                        @($script:updateFixture)
                    }
                    'SourceUpdates' {
                        @()
                    }
                    default {
                        throw "Unexpected menu action in fixture: $Action"
                    }
                }
            }
            Mock Read-PwWorkshopPagedTable {
                $selection = $script:updateSelections[
                    $script:updateSelectionIndex
                ]
                $script:updateSelectionIndex++
                $selection
            }
            Mock Read-Host {
                'M'
            }
            Mock Open-PwNexusModPage {
                [PSCustomObject]@{
                    ModId = $ModId
                    Url = 'https://www.nexusmods.com/palworld/mods/1234'
                    Launched = $true
                }
            }
            Mock Save-PwNexusModUpdate {
                throw 'The direct downloader should not run in manual mode.'
            }
            Mock Write-Host {}

            Start-PwWorkshop -NoClear

            Assert-MockCalled Open-PwNexusModPage `
                -Times 1 `
                -Scope It `
                -ParameterFilter {
                    $ModId -eq 1234 -and $Launch
                }
            Assert-MockCalled Save-PwNexusModUpdate -Times 0 -Scope It
        }
    }
}

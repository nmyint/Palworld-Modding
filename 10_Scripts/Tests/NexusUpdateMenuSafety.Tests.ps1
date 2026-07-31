<#
.SYNOPSIS
    Verifies fail-closed behavior for refreshed Nexus menu reports.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding Nexus update menu safety' {

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

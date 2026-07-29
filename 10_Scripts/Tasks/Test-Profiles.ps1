<#
.SYNOPSIS
    Validates every workshop profile.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

$results = @(
    Get-PwProfiles |
        ForEach-Object {
            Test-PwProfile -Name $_.Name
        }
)

$results | Format-List

if ($results | Where-Object { -not $_.IsValid }) {
    exit 1
}

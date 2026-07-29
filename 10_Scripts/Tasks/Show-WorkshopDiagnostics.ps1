<#
.SYNOPSIS
    Displays the combined workshop recovery and health report.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

Get-PwDiagnostics |
    Format-List

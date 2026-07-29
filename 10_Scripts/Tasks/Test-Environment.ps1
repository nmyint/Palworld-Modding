<#
.SYNOPSIS
    Validates the local workshop environment.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

$result = Test-PwEnvironment
$result | Format-List

if (-not $result.IsReady) {
    exit 1
}

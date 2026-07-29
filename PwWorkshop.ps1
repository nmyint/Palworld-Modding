<#
.SYNOPSIS
    Starts the interactive Palworld Modding Workshop.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path `
    $PSScriptRoot `
    '10_Scripts\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

Start-PwWorkshop

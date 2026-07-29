<#
.SYNOPSIS
    Displays the active profile's deployment preview.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

$plan = Get-PwDeploymentPlan
$plan | Format-List
$plan.Files | Format-Table Action, RelativePath, DestinationPath

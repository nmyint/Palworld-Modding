<#
.SYNOPSIS
    Displays deployment and restoration history.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

Get-PwDeploymentHistory |
    Format-Table Timestamp, Type, Profile, Status, FileCount, IsValid

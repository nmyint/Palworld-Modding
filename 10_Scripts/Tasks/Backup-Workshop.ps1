<#
.SYNOPSIS
    Creates an external maximum-compression workshop backup.
#>

[CmdletBinding()]
param(
    [string]$DestinationRoot = ''
)

Set-StrictMode -Version Latest

$moduleManifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

$parameters = @{}

if (-not [string]::IsNullOrWhiteSpace($DestinationRoot)) {
    $parameters.DestinationRoot = $DestinationRoot
}

New-PwWorkshopBackup @parameters |
    Format-List

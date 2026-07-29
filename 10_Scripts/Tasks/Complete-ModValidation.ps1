<#
.SYNOPSIS
    Records successful in-game validation and cleans temporary mod artifacts.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$Version,

    [string]$Notes = ''
)

Set-StrictMode -Version Latest

$moduleManifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

Complete-PwModInstallation `
    -Name $Name `
    -Version $Version `
    -GameValidated `
    -Notes $Notes `
    -Apply

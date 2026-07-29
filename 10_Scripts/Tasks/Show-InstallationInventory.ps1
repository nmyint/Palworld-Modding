<#
.SYNOPSIS
    Displays known-good installed mods and current verification status.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

Get-PwInstallationInventory |
    Format-Table Name, Version, Profile, Status, FileCount, ValidatedAt

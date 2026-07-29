<#
.SYNOPSIS
    Restores an explicitly selected, validated deployment backup.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

Set-StrictMode -Version Latest

$moduleManifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

Restore-PwDeployment -Path $Path -Apply |
    Format-List

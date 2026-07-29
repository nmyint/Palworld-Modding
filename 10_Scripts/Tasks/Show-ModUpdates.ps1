<#
.SYNOPSIS
    Checks cataloged Nexus mods for available updates.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $manifest -Force

Get-PwModUpdateReport |
    Select-Object `
        Name,
        NexusModId,
        LocalVersion,
        RemoteVersion,
        Status,
        ManualUrl |
    Format-Table -AutoSize

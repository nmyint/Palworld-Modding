<#
.SYNOPSIS
    Checks optional configured Nexus Mods and GitHub release sources.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $manifest -Force

Get-PwSourceUpdateReport |
    Select-Object `
        Name,
        Provider,
        LocalVersion,
        RemoteVersion,
        RemoteFileName,
        Status,
        DownloadUrl |
    Format-Table -AutoSize

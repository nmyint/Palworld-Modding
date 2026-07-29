<#
.SYNOPSIS
    Displays the read-only mod catalog.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $manifest -Force

$catalog = Get-PwModCatalog
$catalog.Mods |
    Select-Object `
        Name,
        Enabled,
        ArchiveMatchStatus,
        LatestCandidateVersion,
        Types |
    Format-Table -AutoSize

Write-Host ''
$catalog |
    Select-Object `
        ModCount,
        ArchiveCount,
        MatchedModCount,
        MissingArchiveCount,
        ArchiveOnlyCount,
        ModsJsonValid |
    Format-List

if ($catalog.Warnings.Count -gt 0) {
    Write-Host 'Warnings:' -ForegroundColor Yellow

    foreach ($warning in $catalog.Warnings) {
        Write-Host " - $warning" -ForegroundColor Yellow
    }
}

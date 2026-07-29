<#
.SYNOPSIS
    Displays a read-only deployment restore plan.
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

$plan = Get-PwRestorePlan -Path $Path
$plan.Files |
    Format-Table Action, RelativePath, DestinationPath
$plan |
    Select-Object `
        Profile,
        ManifestPath,
        CreateCount,
        UpdateCount,
        UnchangedCount,
        CanRestore |
    Format-List

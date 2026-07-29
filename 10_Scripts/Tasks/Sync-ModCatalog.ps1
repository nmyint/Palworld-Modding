<#
.SYNOPSIS
    Previews or applies the persistent mod catalog synchronization.
#>

[CmdletBinding()]
param(
    [switch]$Apply,

    [switch]$SkipContentInspection
)

Set-StrictMode -Version Latest

$moduleManifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

if ($Apply) {
    Update-PwModCatalog `
        -SkipContentInspection:$SkipContentInspection
}
else {
    Get-PwModCatalogSyncPlan `
        -SkipContentInspection:$SkipContentInspection
}

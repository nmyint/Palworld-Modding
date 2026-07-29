<#
.SYNOPSIS
    Fetches and optionally stores Nexus metadata for missing-archive mods.
#>

[CmdletBinding()]
param(
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifest = Join-Path `
    $PSScriptRoot `
    '..\Modules\PalworldModding.psd1'
Import-Module $manifest -Force

$result = if ($Apply) {
    Update-PwNexusCatalogMetadata -Confirm:$false
}
else {
    Get-PwNexusCatalogMetadataReport
}

$result |
    Select-Object `
        CatalogKey,
        SearchTerm,
        NexusModId,
        RemoteName,
        RemoteVersion,
        NameMatch,
        Status,
        GitSources |
    Format-Table -AutoSize

<#
.SYNOPSIS
    Displays a read-only inspection of a downloaded mod archive.
.PARAMETER Path
    Path to the archive to inspect.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'
Import-Module $moduleManifest -Force

$result = Get-PwModArchiveInfo -Path $Path
$result | Format-List
$result.Entries |
    Format-Table ArchivePath, Category, DeploymentRelativePath, ReviewRequired

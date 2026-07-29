<#
.SYNOPSIS
    Validates a deployment backup and displays its file status.
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

$result = Test-PwBackup -Path $Path
$result.Files |
    Format-Table RelativePath, Status, ExpectedHash
$result |
    Select-Object ManifestPath, IsValid, Errors |
    Format-List

if (-not $result.IsValid) {
    exit 1
}

<#
.SYNOPSIS
    Launches the modular pw-git application.
.DESCRIPTION
    Preserves the repository-root entry point while delegating all behavior to
    10_Scripts/Git/pw-git.ps1, the single authoritative implementation.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('menu', 'check', 'compare', 'pull', 'pull-selected', 'push', 'status', 'commit', 'log', 'help')]
    [string]$Command = 'menu',
    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$CommandArguments
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$entryPoint = Join-Path $PSScriptRoot '10_Scripts\Git\pw-git.ps1'
if (-not (Test-Path -LiteralPath $entryPoint -PathType Leaf)) {
    throw "The modular pw-git entry point was not found: $entryPoint"
}
$arguments = @($Command) + @($CommandArguments)
& $entryPoint @arguments

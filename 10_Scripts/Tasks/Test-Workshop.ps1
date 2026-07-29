<#
.SYNOPSIS
    Runs the workshop Pester test suite.
.DESCRIPTION
    Provides a short, reusable entry point for VS Code and manual validation.
#>

Set-StrictMode -Version Latest

$testRoot = Join-Path $PSScriptRoot '..\Tests'
$result = Invoke-Pester -Path $testRoot -PassThru

if ($result.FailedCount -gt 0) {
    exit 1
}

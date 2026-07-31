<#
.SYNOPSIS
    Dedicated bootstrap loader for pw-git.

.DESCRIPTION
    Loads Git-only dependencies. This intentionally does not load the
    Palworld Modding Workshop module or PwWorkshop UX.

.NOTES
    Supported runtime: PowerShell 7.6.4 (pwsh).
#>

Set-StrictMode -Version Latest

function Initialize-PwGit {
    [CmdletBinding()]
    param()

    $gitRoot = Split-Path -Parent $PSScriptRoot
    $sharedRoot = Join-Path $gitRoot '..\Shared'
    $commandsRoot = Join-Path $PSScriptRoot 'Commands'

    $dependencies = @(
        (Join-Path $sharedRoot 'GitHelpers.ps1'),
        (Join-Path $sharedRoot 'GitValidation.ps1')
    )

    foreach ($dependency in $dependencies) {
        if (-not (Test-Path -LiteralPath $dependency -PathType Leaf)) {
            throw "pw-git dependency missing: $dependency"
        }

        . $dependency
    }

    [pscustomobject]@{
        GitRoot = $gitRoot
        CommandsRoot = $commandsRoot
    }
}

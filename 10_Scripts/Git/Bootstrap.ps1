<#
.SYNOPSIS
    Dedicated bootstrap loader for pw-git.

.DESCRIPTION
    Resolves the repository and Git-tool paths, loads Git-only helper scripts,
    validates required dependencies, and returns the pw-git runtime context.

    This bootstrap intentionally does not load the Palworld Modding Workshop
    module, PwWorkshop UX, mod commands, profiles, or deployment tooling.

.NOTES
    Supported runtime: PowerShell 7.6.4 or later in the 7.x line (pwsh).
    Windows PowerShell 5.1 is not supported.
#>

Set-StrictMode -Version Latest

$script:PwGitScriptRoot = $PSScriptRoot
$script:PwGitScriptsRoot = Split-Path -Parent $script:PwGitScriptRoot
$script:PwGitRepositoryRoot = Split-Path -Parent $script:PwGitScriptsRoot
$script:PwGitCommandsRoot = Join-Path $script:PwGitScriptRoot 'Commands'
$script:PwGitSharedRoot = Join-Path $script:PwGitScriptsRoot 'Shared'

$script:PwGitDependencyFiles = @(
    (Join-Path $script:PwGitSharedRoot 'GitHelpers.ps1')
    (Join-Path $script:PwGitSharedRoot 'GitValidation.ps1')
)

# Dot-source dependencies at script scope so their functions remain available
# after Initialize-PwGit returns.
foreach ($dependencyPath in $script:PwGitDependencyFiles) {
    if (-not (Test-Path -LiteralPath $dependencyPath -PathType Leaf)) {
        throw "pw-git dependency missing: $dependencyPath"
    }

    . $dependencyPath
}

function Assert-PwGitRuntimeDependencies {
    [CmdletBinding()]
    param()

    $requiredFunctions = @(
        'Invoke-PwGitNative'
        'Get-PwGitBranch'
        'Get-PwGitChangeState'
        'Get-PwGitDivergence'
        'Assert-PwGitWritableState'
    )

    $missingFunctions = @(
        foreach ($functionName in $requiredFunctions) {
            if ($null -eq (Get-Command $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
                $functionName
            }
        }
    )

    if ($missingFunctions.Count -gt 0) {
        throw "pw-git failed to load required functions: $($missingFunctions -join ', ')"
    }
}

function Initialize-PwGit {
    [CmdletBinding()]
    param()

    $minimumVersion = [version]'7.6.4'
    $currentVersion = $PSVersionTable.PSVersion

    if ($currentVersion.Major -ne 7 -or $currentVersion -lt $minimumVersion) {
        throw "pw-git requires PowerShell 7.6.4 or later in the 7.x line. Current version: $currentVersion"
    }

    if ($null -eq (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'pw-git requires Git to be available on PATH.'
    }

    if (-not (Test-Path -LiteralPath $script:PwGitRepositoryRoot -PathType Container)) {
        throw "pw-git repository root was not found: $script:PwGitRepositoryRoot"
    }

    if (-not (Test-Path -LiteralPath (Join-Path $script:PwGitRepositoryRoot '.git'))) {
        throw "pw-git repository root is not a Git repository: $script:PwGitRepositoryRoot"
    }

    if (-not (Test-Path -LiteralPath $script:PwGitCommandsRoot -PathType Container)) {
        throw "pw-git commands directory was not found: $script:PwGitCommandsRoot"
    }

    Assert-PwGitRuntimeDependencies

    [pscustomobject]@{
        Application = 'pw-git'
        RepositoryRoot = $script:PwGitRepositoryRoot
        GitScriptRoot = $script:PwGitScriptRoot
        CommandsRoot = $script:PwGitCommandsRoot
        SharedRoot = $script:PwGitSharedRoot
        RequiredPowerShellVersion = $minimumVersion
        CurrentPowerShellVersion = $currentVersion
        InitializedAt = Get-Date
    }
}

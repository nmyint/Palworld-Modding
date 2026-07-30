<#
.SYNOPSIS
    Context-aware command entry point for pw-git.

.DESCRIPTION
    Initializes the Palworld Modding Workshop, resolves the repository root,
    loads the requested command module, and executes it from the repository
    root. This file is intentionally a thin dispatcher; Git behavior belongs
    in Commands\*.ps1 and shared behavior belongs in ..\Shared\GitHelpers.ps1.

.EXAMPLE
    .\10_Scripts\Git\pw-git.ps1 check

.EXAMPLE
    .\10_Scripts\Git\pw-git.ps1 compare
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet(
        'check',
        'compare',
        'pull',
        'push',
        'status',
        'commit',
        'log',
        'help'
    )]
    [string]$Command = 'help',

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$CommandArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gitScriptRoot = $PSScriptRoot
$bootstrapPath = Join-Path $gitScriptRoot '..\Core\Bootstrap.ps1'
$sharedHelpersPath = Join-Path $gitScriptRoot '..\Shared\GitHelpers.ps1'
$commandsRoot = Join-Path $gitScriptRoot 'Commands'

function Show-PwGitHelp {
    [CmdletBinding()]
    param()

    @'
pw-git - Palworld Modding Workshop Git tooling

Usage:
  pw-git <command> [arguments]

Commands:
  check      Verify Git, repository, branch, remote, and workshop health
  compare    Compare the local working copy with its upstream repository branch
  pull       Safely pull repository changes into the local working copy
  push       Review, commit, and push local changes
  status     Show concise local and repository status
  commit     Create a reviewed local commit
  log        Show recent repository history
  help       Show this help

Examples:
  pw-git check
  pw-git compare
  pw-git pull
  pw-git push
'@ | Write-Host
}

function Get-PwGitCommandDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $definitions = @{
        check = [pscustomobject]@{
            File = 'Check.ps1'
            Function = 'Invoke-PwGitCheck'
        }
        compare = [pscustomobject]@{
            File = 'Compare.ps1'
            Function = 'Invoke-PwGitCompare'
        }
        pull = [pscustomobject]@{
            File = 'Pull.ps1'
            Function = 'Invoke-PwGitPull'
        }
        push = [pscustomobject]@{
            File = 'Push.ps1'
            Function = 'Invoke-PwGitPush'
        }
        status = [pscustomobject]@{
            File = 'Status.ps1'
            Function = 'Invoke-PwGitStatus'
        }
        commit = [pscustomobject]@{
            File = 'Commit.ps1'
            Function = 'Invoke-PwGitCommit'
        }
        log = [pscustomobject]@{
            File = 'Log.ps1'
            Function = 'Invoke-PwGitLog'
        }
    }

    return $definitions[$Name]
}

if ($Command -eq 'help') {
    Show-PwGitHelp
    return
}

if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
    throw "Workshop bootstrap was not found: $bootstrapPath"
}

. $bootstrapPath
$context = Initialize-PwWorkshop
$repositoryRoot = $context.WorkshopRoot

if ([string]::IsNullOrWhiteSpace($repositoryRoot)) {
    throw 'Initialize-PwWorkshop did not return a workshop root.'
}

if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot '.git'))) {
    throw "Workshop root is not a Git repository: $repositoryRoot"
}

if (Test-Path -LiteralPath $sharedHelpersPath -PathType Leaf) {
    . $sharedHelpersPath
}

$definition = Get-PwGitCommandDefinition -Name $Command
if ($null -eq $definition) {
    throw "Unsupported pw-git command: $Command"
}

$commandPath = Join-Path $commandsRoot $definition.File
if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
    throw (
        "The pw-git '$Command' command has not been implemented yet. " +
        "Expected command file: $commandPath"
    )
}

. $commandPath

$commandFunction = Get-Command $definition.Function -CommandType Function -ErrorAction SilentlyContinue
if ($null -eq $commandFunction) {
    throw (
        "Command file '$commandPath' did not define the expected function " +
        "'$($definition.Function)'."
    )
}

Push-Location $repositoryRoot
try {
    & $definition.Function -Context $context -Arguments $CommandArguments
}
finally {
    Pop-Location
}

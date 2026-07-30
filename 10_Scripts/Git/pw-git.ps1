<#
.SYNOPSIS
    Context-aware command entry point for pw-git.

.DESCRIPTION
    Initializes the Palworld Modding Workshop, resolves the repository root,
    and opens the interactive menu or dispatches a direct command. Git behavior
    belongs in Commands\*.ps1, menu behavior belongs in Menu.ps1, and shared
    behavior belongs in ..\Shared\GitHelpers.ps1.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('menu','check','compare','pull','push','status','commit','log','help')]
    [string]$Command = 'menu',

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$CommandArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gitScriptRoot = $PSScriptRoot
$bootstrapPath = Join-Path $gitScriptRoot '..\Core\Bootstrap.ps1'
$sharedHelpersPath = Join-Path $gitScriptRoot '..\Shared\GitHelpers.ps1'
$menuPath = Join-Path $gitScriptRoot 'Menu.ps1'
$commandsRoot = Join-Path $gitScriptRoot 'Commands'
$script:PwGitCommandsRoot = $commandsRoot

function Show-PwGitHelp {
    [CmdletBinding()]
    param()

    @'
pw-git - Palworld Modding Workshop Git tooling

Usage:
  pw-git
  pw-git <command> [arguments]

Commands:
  menu       Open the interactive menu
  check      Verify Git, repository, branch, remote, and workshop health
  compare    Compare the local working copy with its upstream repository branch
  pull       Safely pull repository changes into the local working copy
  push       Review, commit, and push local changes
  status     Show concise local and repository status
  commit     Create a reviewed local commit
  log        Show recent repository history
  help       Show this help

Examples:
  pw-git
  pw-git check
  pw-git compare
  pw-git pull
  pw-git push
'@ | Write-Host
}

function Get-PwGitCommandDefinition {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $definitions = @{
        check   = [pscustomobject]@{ File = 'Check.ps1';   Function = 'Invoke-PwGitCheck' }
        compare = [pscustomobject]@{ File = 'Compare.ps1'; Function = 'Invoke-PwGitCompare' }
        pull    = [pscustomobject]@{ File = 'Pull.ps1';    Function = 'Invoke-PwGitPull' }
        push    = [pscustomobject]@{ File = 'Push.ps1';    Function = 'Invoke-PwGitPush' }
        status  = [pscustomobject]@{ File = 'Status.ps1';  Function = 'Invoke-PwGitStatus' }
        commit  = [pscustomobject]@{ File = 'Commit.ps1';  Function = 'Invoke-PwGitCommit' }
        log     = [pscustomobject]@{ File = 'Log.ps1';     Function = 'Invoke-PwGitLog' }
    }

    $definitions[$Name]
}

if ($Command -eq 'help') {
    Show-PwGitHelp
    return
}

if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
    throw "Workshop bootstrap was not found: $bootstrapPath"
}

if (-not (Test-Path -LiteralPath $sharedHelpersPath -PathType Leaf)) {
    throw "pw-git shared helpers were not found: $sharedHelpersPath"
}

. $bootstrapPath
. $sharedHelpersPath

$context = Initialize-PwWorkshop
$repositoryRoot = [string]$context.WorkshopRoot

if ([string]::IsNullOrWhiteSpace($repositoryRoot)) {
    throw 'Initialize-PwWorkshop did not return a workshop root.'
}

if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot '.git'))) {
    throw "Workshop root is not a Git repository: $repositoryRoot"
}

Push-Location $repositoryRoot
try {
    if ($Command -eq 'menu') {
        if (-not (Test-Path -LiteralPath $menuPath -PathType Leaf)) {
            throw "pw-git menu was not found: $menuPath"
        }

        . $menuPath
        Show-PwGitMenu -Context $context
        return
    }

    $definition = Get-PwGitCommandDefinition -Name $Command
    if ($null -eq $definition) {
        throw "Unsupported pw-git command: $Command"
    }

    $commandPath = Join-Path $commandsRoot $definition.File
    if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        throw "The pw-git '$Command' command has not been implemented yet. Expected command file: $commandPath"
    }

    . $commandPath

    $commandFunction = Get-Command $definition.Function -CommandType Function -ErrorAction SilentlyContinue
    if ($null -eq $commandFunction) {
        throw "Command file '$commandPath' did not define '$($definition.Function)'."
    }

    & $definition.Function -Context $context -Arguments @($CommandArguments)
}
finally {
    Pop-Location
}

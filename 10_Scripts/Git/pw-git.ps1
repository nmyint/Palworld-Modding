<#
.SYNOPSIS
    Git-only command entry point for Pw-Git.
.DESCRIPTION
    Initializes the dedicated Pw-Git runtime, resolves the repository root, and
    opens the interactive Git menu or dispatches a direct Git command.
    Pw-Git is intentionally separate from PwWorkshop. It does not load the
    Palworld Modding Workshop module, mod-management UX, profiles, deployment,
    or other workshop commands.
.NOTES
    Supported runtime: PowerShell 7.6.4 or later in the 7.x line (pwsh).
    Windows PowerShell 5.1 is not supported.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet(
        'menu',
        'check',
        'compare',
        'pull',
        'pull-selected',
        'push',
        'status',
        'commit',
        'log',
        'help'
    )]
    [string]$Command = 'menu',
    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$CommandArguments
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$gitScriptRoot = $PSScriptRoot
$bootstrapPath = Join-Path $gitScriptRoot 'Bootstrap.ps1'
$menuPath = Join-Path $gitScriptRoot 'Menu.ps1'
function Show-PwGitHelp {
    [CmdletBinding()]
    param()
    @'
Pw-Git - Git tooling for the Palworld-Modding repository

Runtime:
  PowerShell 7.6.4 or later in the 7.x line (pwsh)
  Windows PowerShell 5.1 is not supported.

Usage:
  pw-git
  pw-git <command> [arguments]

Commands:
  menu           Open the interactive Git menu
  check          Verify Git, repository, branch, remote, and runtime health
  compare        Compare the local branch with its upstream branch
  pull           Safely pull repository changes into the local working copy
  pull-selected  Update selected working-tree files from the upstream branch
  push           Review, commit, and push local changes
  status         Show concise local repository status
  commit         Create a reviewed local commit
  log            Show recent repository history
  help           Show this help

Interactive controls:
  Enter or B     Cancel the current action and return to the menu
  Q              Quit Pw-Git
  Ctrl-C         Interrupt immediately

Examples:
  pw-git
  pw-git check
  pw-git compare
  pw-git pull
  pw-git pull-selected
  pw-git push
'@ | Write-Host
}
function Get-PwGitCommandDefinition {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    $definitions = @{
        check = [pscustomobject]@{ File = 'Check.ps1'; Function = 'Invoke-PwGitCheck' }
        compare = [pscustomobject]@{ File = 'Compare.ps1'; Function = 'Invoke-PwGitCompare' }
        pull = [pscustomobject]@{ File = 'Pull.ps1'; Function = 'Invoke-PwGitPull' }
        'pull-selected' = [pscustomobject]@{ File = 'PullSelected.ps1'; Function = 'Invoke-PwGitPullSelected' }
        push = [pscustomobject]@{ File = 'Push.ps1'; Function = 'Invoke-PwGitPush' }
        status = [pscustomobject]@{ File = 'Status.ps1'; Function = 'Invoke-PwGitStatus' }
        commit = [pscustomobject]@{ File = 'Commit.ps1'; Function = 'Invoke-PwGitCommit' }
        log = [pscustomobject]@{ File = 'Log.ps1'; Function = 'Invoke-PwGitLog' }
    }
    $definitions[$Name]
}
if ($Command -eq 'help') {
    Show-PwGitHelp
    return
}
if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
    throw "Pw-Git bootstrap was not found: $bootstrapPath"
}
. $bootstrapPath
$context = Initialize-PwGit
$repositoryRoot = [string]$context.RepositoryRoot
$commandsRoot = [string]$context.CommandsRoot
$script:PwGitCommandsRoot = $commandsRoot
if ([string]::IsNullOrWhiteSpace($repositoryRoot)) {
    throw 'Initialize-PwGit did not return a repository root.'
}
Push-Location $repositoryRoot
try {
    if ($Command -eq 'menu') {
        if (-not (Test-Path -LiteralPath $menuPath -PathType Leaf)) {
            throw "Pw-Git menu was not found: $menuPath"
        }
        . $menuPath
        Show-PwGitMenu -Context $context
        return
    }
    $definition = Get-PwGitCommandDefinition -Name $Command
    if ($null -eq $definition) {
        throw "Unsupported Pw-Git command: $Command"
    }
    $commandPath = Join-Path $commandsRoot $definition.File
    if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        throw "The Pw-Git '$Command' command has not been implemented. Expected: $commandPath"
    }
    . $commandPath
    $commandFunction = Get-Command $definition.Function -CommandType Function -ErrorAction SilentlyContinue
    if ($null -eq $commandFunction) {
        throw "Command file '$commandPath' did not define '$($definition.Function)'."
    }
    try {
        & $definition.Function -Context $context -Arguments @($CommandArguments)
    }
    catch [System.OperationCanceledException] {
        if ($_.Exception.Message -notin @('PWGIT_BACK', 'PWGIT_QUIT')) {
            throw
        }
    }
}
finally {
    Pop-Location
}

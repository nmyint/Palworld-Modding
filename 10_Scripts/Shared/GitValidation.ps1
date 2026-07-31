<#
.SYNOPSIS
    Repository state validation helpers for pw-git.

    PowerShell 7.6.4 compatible.
#>

Set-StrictMode -Version Latest

function Test-PwGitDetachedHead {
    [CmdletBinding()]
    param()

    [string]::IsNullOrWhiteSpace((Get-PwGitBranch))
}

function Test-PwGitRemote {
    [CmdletBinding()]
    param()

    $result = Invoke-PwGitNative -Arguments @('remote', 'get-url', 'origin') -AllowFailure -PassThru
    $result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($result.Output -join ''))
}

function Test-PwGitUpstream {
    [CmdletBinding()]
    param()

    -not [string]::IsNullOrWhiteSpace((Get-PwGitUpstream))
}

function Get-PwGitConflictFiles {
    [CmdletBinding()]
    param()

    @(
        Invoke-PwGitNative -Arguments @('diff', '--name-only', '--diff-filter=U')
    )
}

function Test-PwGitConflicts {
    [CmdletBinding()]
    param()

    @(Get-PwGitConflictFiles).Count -gt 0
}

function Get-PwGitChangeState {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        Staged = @(Invoke-PwGitNative -Arguments @('diff', '--cached', '--name-only')).Count
        Unstaged = @(Invoke-PwGitNative -Arguments @('diff', '--name-only')).Count
        Conflicts = @(Get-PwGitConflictFiles).Count
    }
}

function Test-PwGitMixedChanges {
    [CmdletBinding()]
    param()

    $state = Get-PwGitChangeState
    $state.Staged -gt 0 -and $state.Unstaged -gt 0
}

function Assert-PwGitWritableState {
    [CmdletBinding()]
    param()

    if (Test-PwGitDetachedHead) {
        throw 'Repository is in detached HEAD state. Switch to a branch before committing or pushing.'
    }

    if (Test-PwGitConflicts) {
        throw 'Repository contains unresolved merge conflicts. Resolve them before continuing.'
    }
}

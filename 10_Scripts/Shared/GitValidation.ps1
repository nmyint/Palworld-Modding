<#
.SYNOPSIS
    Repository-state validation helpers for pw-git.
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
    -not [string]::IsNullOrWhiteSpace((Get-PwGitOriginUrl))
}
function Test-PwGitUpstream {
    [CmdletBinding()]
    param()
    -not [string]::IsNullOrWhiteSpace((Get-PwGitUpstream))
}
function Get-PwGitConflictFiles {
    [CmdletBinding()]
    param()
    [string[]]@(
        Invoke-PwGitNative -Arguments @('diff', '--name-only', '--diff-filter=U', '--') |
            ForEach-Object { ([string]$_).Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
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
    $staged = 0
    $unstaged = 0
    $untracked = 0
    $conflicts = 0
    $conflictCodes = @('DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU')
    foreach ($item in @(Get-PwGitSelectableFiles)) {
        $code = [string]$item.Status
        if ($code -eq '??') {
            $untracked++
            continue
        }
        if ($conflictCodes -contains $code) {
            $conflicts++
        }
        if ($code.Length -ge 1 -and $code[0] -ne ' ') {
            $staged++
        }
        if ($code.Length -ge 2 -and $code[1] -ne ' ') {
            $unstaged++
        }
    }
    [pscustomobject]@{
        Staged = $staged
        Unstaged = $unstaged
        Untracked = $untracked
        Conflicts = $conflicts
    }
}
function Test-PwGitMixedChanges {
    [CmdletBinding()]
    param()
    $state = Get-PwGitChangeState
    $state.Staged -gt 0 -and ($state.Unstaged -gt 0 -or $state.Untracked -gt 0)
}
function Get-PwGitDivergence {
    [CmdletBinding()]
    param([string]$Upstream)
    if ([string]::IsNullOrWhiteSpace($Upstream)) {
        $Upstream = Assert-PwGitUpstream
    }
    Get-PwGitAheadBehind -Upstream $Upstream
}
function Test-PwGitDiverged {
    [CmdletBinding()]
    param([string]$Upstream)
    $state = Get-PwGitDivergence -Upstream $Upstream
    $state.Ahead -gt 0 -and $state.Behind -gt 0
}
function Assert-PwGitWritableState {
    [CmdletBinding()]
    param()
    if (Test-PwGitDetachedHead) {
        throw 'Repository is in detached HEAD state. Switch to a branch before committing or pushing.'
    }
    if (Test-PwGitConflicts) {
        $files = @(Get-PwGitConflictFiles)
        throw "Repository contains unresolved merge conflicts: $($files -join ', '). Resolve them before continuing."
    }
}

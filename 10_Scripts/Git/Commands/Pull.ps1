<#
.SYNOPSIS
    Safely pulls repository changes using fast-forward only.
#>
Set-StrictMode -Version Latest
function Invoke-PwGitPull {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'Pull from Repository'
    Assert-PwGitWritableState
    if (-not (Test-PwGitRemote)) {
        throw 'No origin remote configured.'
    }
    $upstream = Assert-PwGitUpstream
    if (-not (Test-PwGitClean)) {
        throw 'Pull cancelled because the local working tree contains changes.'
    }
    Write-Host "Refreshing ${upstream} before pull."
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('fetch', '--prune'))
    if (Test-PwGitDiverged -Upstream $upstream) {
        throw "Branches have diverged from ${upstream}. Rebase or reconcile before pulling."
    }
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('pull', '--ff-only'))
    Write-Host '[ OK ] Pull completed.'
}

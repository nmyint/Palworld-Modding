<#
.SYNOPSIS
    Reviews, commits, and pushes local changes.
#>
Set-StrictMode -Version Latest
function Invoke-PwGitPush {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'Commit and Push Changes'
    Assert-PwGitWritableState
    if (-not (Test-PwGitRemote)) {
        throw 'No origin remote configured.'
    }
    $upstream = Assert-PwGitUpstream
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('fetch', '--prune'))
    if (Test-PwGitDiverged -Upstream $upstream) {
        throw "Branches have diverged from $upstream. Rebase or reconcile before pushing."
    }
    $paths = @($Arguments | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($paths.Count -gt 0) {
        foreach ($path in $paths) {
            Invoke-PwGitNative -Arguments @('add', '--', $path) | Out-Null
        }
    }
    else {
        Invoke-PwGitNative -Arguments @('add', '--all') | Out-Null
    }
    if (-not (Test-PwGitStagedChanges)) {
        throw 'No staged changes were found after staging.'
    }
    $message = Read-PwGitCommitMessage
    Write-Host "Branch         : $(Get-PwGitBranch)"
    Write-Host "Commit message : $message"
    Write-Host ''
    Write-PwGitStagedSummary
    if (-not (Confirm-PwGitAction -Prompt 'Commit and push these changes?')) {
        Write-Host '[INFO] Push cancelled.'
        return
    }
    Invoke-PwGitNative -Arguments @('commit', '-m', $message) | Out-Null
    Invoke-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('push'))
    Write-Host '[ OK ] Commit and push completed.'
}

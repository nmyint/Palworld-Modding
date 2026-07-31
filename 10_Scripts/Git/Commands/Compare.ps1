<#
.SYNOPSIS
    Compares local branch state with its upstream branch.
#>
Set-StrictMode -Version Latest
function Invoke-PwGitCompare {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'Local and Repository Comparison'
    Assert-PwGitWritableState
    $upstream = Assert-PwGitUpstream
    Write-Host "Refreshing ${upstream} before comparison."
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('fetch', '--prune'))
    $comparison = Get-PwGitAheadBehind -Upstream $upstream
    Write-Host "Local branch : $(Get-PwGitBranch)"
    Write-Host "Repo branch  : ${upstream}"
    Write-Host "Ahead        : $($comparison.Ahead) commit(s)"
    Write-Host "Behind       : $($comparison.Behind) commit(s)"
    Write-Host ''
    [string[]]$status = @(Get-PwGitStatusLines)
    if ($status.Count -eq 0) {
        Write-Host '[ OK ] No uncommitted local changes.'
    }
    else {
        Write-Host 'Uncommitted local changes:'
        $status | ForEach-Object { Write-Host "  $_" }
    }
    if ($comparison.Ahead -gt 0) {
        Write-Host ''
        Write-Host 'Commits only in local:'
        Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('log', '--oneline', "${upstream}..HEAD"))
    }
    if ($comparison.Behind -gt 0) {
        Write-Host ''
        Write-Host 'Commits only in repository:'
        Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('log', '--oneline', "HEAD..${upstream}"))
    }
    if ($comparison.Ahead -gt 0 -and $comparison.Behind -gt 0) {
        Write-Host ''
        Write-Warning 'Branches have diverged.'
    }
}

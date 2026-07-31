<#
.SYNOPSIS
    Reports pw-git runtime and repository health.
#>
Set-StrictMode -Version Latest
function Invoke-PwGitCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'pw-git Health Check'
    $gitVersion = Invoke-PwGitNative -Arguments @('--version') -AllowFailure -PassThru
    $branch = Get-PwGitBranch
    $upstream = Get-PwGitUpstream
    $originUrl = Get-PwGitOriginUrl
    $state = Get-PwGitChangeState
    $hasUpstream = -not [string]::IsNullOrWhiteSpace($upstream)
    $hasConflicts = Test-PwGitConflicts
    $checks = @(
        [pscustomobject]@{ Name = 'pw-git runtime'; Passed = $Context.Application -eq 'pw-git'; Details = "PowerShell $($Context.CurrentPowerShellVersion)" }
        [pscustomobject]@{ Name = 'Repository root'; Passed = Test-Path -LiteralPath (Join-Path $Context.RepositoryRoot '.git'); Details = $Context.RepositoryRoot }
        [pscustomobject]@{ Name = 'Git available'; Passed = $gitVersion.ExitCode -eq 0; Details = ($gitVersion.Output -join ' ').Trim() }
        [pscustomobject]@{ Name = 'Current branch'; Passed = -not [string]::IsNullOrWhiteSpace($branch); Details = $(if ($branch) { $branch } else { 'Detached HEAD' }) }
        [pscustomobject]@{ Name = 'Origin remote'; Passed = -not [string]::IsNullOrWhiteSpace($originUrl); Details = $(if ($originUrl) { $originUrl } else { 'Missing' }) }
        [pscustomobject]@{ Name = 'Upstream branch'; Passed = $hasUpstream; Details = $(if ($hasUpstream) { $upstream } else { 'Not configured' }) }
        [pscustomobject]@{ Name = 'Merge conflicts'; Passed = -not $hasConflicts; Details = $(if ($hasConflicts) { (@(Get-PwGitConflictFiles) -join ', ') } else { 'None' }) }
    )
    foreach ($check in $checks) {
        $label = if ($check.Passed) { '[ OK ]' } else { '[WARN]' }
        Write-Host ('{0} {1}: {2}' -f $label, $check.Name, $check.Details)
    }
    Write-Host ''
    Write-Host 'Change state:'
    Write-Host "  Staged   : $($state.Staged)"
    Write-Host "  Unstaged : $($state.Unstaged)"
    Write-Host "  Untracked: $($state.Untracked)"
    Write-Host "  Conflicts: $($state.Conflicts)"
    if (Test-PwGitMixedChanges) {
        Write-Host '[WARN] Mixed staged and unstaged or untracked changes detected.'
    }
    if (-not $hasUpstream) {
        Write-Host ''
        Write-Host '[INFO] Branch relationship is unavailable until an upstream branch is configured.'
        return
    }
    $divergence = Get-PwGitDivergence -Upstream $upstream
    Write-Host ''
    Write-Host 'Branch relationship:'
    Write-Host "  Ahead : $($divergence.Ahead)"
    Write-Host "  Behind: $($divergence.Behind)"
    if ($divergence.Ahead -gt 0 -and $divergence.Behind -gt 0) {
        Write-Host '[WARN] Local and upstream branches have diverged. Reconcile them before pulling or pushing.'
    }
}

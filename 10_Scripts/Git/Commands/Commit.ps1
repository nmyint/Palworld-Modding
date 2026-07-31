<#
.SYNOPSIS
    Creates a reviewed local commit from staged changes.
#>
Set-StrictMode -Version Latest
function Invoke-PwGitCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'Create Local Commit'
    Assert-PwGitWritableState
    if (-not (Test-PwGitStagedChanges)) {
        Write-Host '[INFO] No staged changes found.'
        return
    }
    if (Test-PwGitMixedChanges) {
        Write-Host '[WARN] Unstaged or untracked changes will not be included in this commit.'
    }
    [string[]]$argumentList = @($Arguments | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $message = if ($argumentList.Count -gt 0) { ($argumentList -join ' ').Trim() } else { Read-PwGitCommitMessage }
    Write-Host "Branch         : $(Get-PwGitBranch)"
    Write-Host "Commit message : $message"
    Write-Host ''
    Write-PwGitStagedSummary
    if (-not (Confirm-PwGitAction -Prompt 'Create this local commit?')) {
        Write-Host '[INFO] Commit cancelled. Staged changes were left unchanged.'
        return
    }
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('commit', '-m', $message))
    Write-Host '[ OK ] Local commit created.'
}

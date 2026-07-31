Set-StrictMode -Version Latest

function Invoke-PwGitCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Context,
        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Create Local Commit'

    Assert-PwGitWritableState

    if (Test-PwGitMixedChanges) {
        Write-Host '[WARN] Mixed staged and unstaged changes detected.'
    }

    if (-not (Test-PwGitStagedChanges)) {
        Write-Host '[INFO] No staged changes found.'
        return
    }

    $message = if (@($Arguments).Count -gt 0) { (@($Arguments) -join ' ').Trim() } else { Read-PwGitCommitMessage }

    if ([string]::IsNullOrWhiteSpace($message)) {
        Write-Host '[WARN] Commit message required.'
        return
    }

    if (-not (Confirm-PwGitAction -Prompt 'Create this local commit?')) {
        Write-Host '[INFO] Commit cancelled. Staged changes were left unchanged.'
        return
    }

    Invoke-PwGitNative -Arguments @('commit', '-m', $message) |
        ForEach-Object { Write-Host $_ }

    Write-Host '[ OK ] Local commit created.'
}

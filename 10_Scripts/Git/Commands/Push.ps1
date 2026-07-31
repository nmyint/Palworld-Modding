Set-StrictMode -Version Latest

function Invoke-PwGitPush {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Context,
        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Commit and Push Changes'

    Assert-PwGitWritableState

    if (-not (Test-PwGitRemote)) {
        throw 'No origin remote configured.'
    }

    if (Test-PwGitDiverged) {
        throw 'Branches have diverged. Rebase before pushing.'
    }

    $status = @(Get-PwGitStatusLines)
    if ($status.Count -eq 0) {
        Write-Host '[INFO] No local changes were found.'
        return
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
    if ([string]::IsNullOrWhiteSpace($message)) {
        throw 'A commit message is required.'
    }

    if (-not (Confirm-PwGitAction -Prompt 'Commit and push these changes?')) {
        return
    }

    Invoke-PwGitNative -Arguments @('commit', '-m', $message) | Out-Null
    Invoke-PwGitNative -Arguments @('push') | Out-Null

    Write-Host '[ OK ] Commit and push completed.'
}

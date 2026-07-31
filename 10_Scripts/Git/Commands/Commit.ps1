Set-StrictMode -Version Latest

function Invoke-PwGitCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context,

        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Create Local Commit'

    if (-not (Test-PwGitStagedChanges)) {
        Write-Host '[INFO] No staged changes found.'
        Write-Host ''
        Write-Host 'Stage files before creating a commit.'
        Write-Host ''
        Write-Host 'Suggested actions:'
        Write-Host '  - Use Push Selected Files to stage and publish changes'
        Write-Host '  - Stage files manually with git add, then retry'
        Write-Host '  - Return to menu'
        return
    }

    $argumentList = @($Arguments)
    $message = if ($argumentList.Count -gt 0) {
        ($argumentList -join ' ').Trim()
    }
    else {
        Read-PwGitCommitMessage
    }

    Write-Host "Branch         : $(Get-PwGitBranch)"
    Write-Host "Commit message : $message"
    Write-Host ''
    Write-Host 'Staged changes:'

    @(Invoke-PwGitNative -Arguments @('diff', '--cached', '--stat')) |
        ForEach-Object { Write-Host "  $_" }

    Write-Host ''
    if (-not (Confirm-PwGitAction -Prompt 'Create this local commit?')) {
        Write-Host '[INFO] Commit cancelled. Staged changes were left unchanged.'
        return
    }

    Invoke-PwGitNative -Arguments @('commit', '-m', $message) |
        ForEach-Object { Write-Host $_ }

    Write-Host '[ OK ] Local commit created.'
}

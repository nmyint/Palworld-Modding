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
        Write-Host 'Options:'
        Write-Host '  1. Return to menu and use Push Selected Files'
        Write-Host '  2. Stage files manually and run Create Local Commit again'
        Write-Host '  Q. Quit pw-git'
        return
    }

    $argumentList = @($Arguments)
    $message = if ($argumentList.Count -gt 0) {
        ($argumentList -join ' ').Trim()
    }
    else {
        Read-PwGitCommitMessage
    }

    if ([string]::IsNullOrWhiteSpace($message)) {
        throw 'A commit message is required.'
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

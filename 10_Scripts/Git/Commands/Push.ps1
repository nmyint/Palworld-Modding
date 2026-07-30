Set-StrictMode -Version Latest

function Invoke-PwGitPush {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context,

        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Commit and Push Changes'

    $status = @(Get-PwGitStatusLines)
    if ($status.Count -eq 0) {
        Write-Host '[INFO] No local changes were found.'
        return
    }

    $paths = @(
        @($Arguments) |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )

    if ($paths.Count -gt 0) {
        Write-Host 'Files selected for staging:'
        $paths | ForEach-Object { Write-Host "  $_" }
    }
    else {
        Write-Host 'All current changes will be staged:'
        $status | ForEach-Object { Write-Host "  $_" }
    }

    Write-Host ''
    if (-not (Confirm-PwGitAction -Prompt 'Stage these changes?')) {
        Write-Host '[INFO] Push cancelled. No files were staged by pw-git.'
        return
    }

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

    Write-Host ''
    Write-Host "Branch         : $(Get-PwGitBranch)"
    $upstream = Get-PwGitUpstream
    Write-Host "Upstream       : $(if ($upstream) { $upstream } else { '<not configured>' })"
    Write-Host "Commit message : $message"
    Write-Host ''
    Write-Host 'Staged changes:'

    @(Invoke-PwGitNative -Arguments @('diff', '--cached', '--stat')) |
        ForEach-Object { Write-Host "  $_" }

    Write-Host ''
    if (-not (Confirm-PwGitAction -Prompt 'Commit and push these changes?')) {
        Write-Host '[INFO] Commit and push cancelled. Staged changes were left unchanged.'
        return
    }

    Invoke-PwGitNative -Arguments @('commit', '-m', $message) |
        ForEach-Object { Write-Host $_ }

    $branch = Get-PwGitBranch

    if ([string]::IsNullOrWhiteSpace($upstream)) {
        Invoke-PwGitNative -Arguments @('push', '--set-upstream', 'origin', $branch) |
            ForEach-Object { Write-Host $_ }
    }
    else {
        Invoke-PwGitNative -Arguments @('push') |
            ForEach-Object { Write-Host $_ }
    }

    Write-Host '[ OK ] Commit and push completed.'
}

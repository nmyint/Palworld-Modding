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
    $comparison = Get-PwGitAheadBehind -Upstream $upstream
    if ($comparison.Behind -gt 0) {
        throw "Local branch is $($comparison.Behind) commit(s) behind ${upstream}. Pull or reconcile before pushing."
    }
    [string[]]$paths = @(
        @($Arguments) |
            ForEach-Object { ([string]$_).Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
    if ($paths.Count -gt 0) {
        [string[]]$stagedPaths = @(Get-PwGitStagedPaths)
        [string[]]$unrelatedStagedPaths = @($stagedPaths | Where-Object { $paths -notcontains $_ })
        if ($unrelatedStagedPaths.Count -gt 0) {
            throw "Selected push stopped because unrelated files are already staged: $($unrelatedStagedPaths -join ', '). Commit or unstage them first."
        }
        foreach ($path in $paths) {
            Invoke-PwGitNative -Arguments @('add', '--', $path) | Out-Null
        }
    }
    else {
        Invoke-PwGitNative -Arguments @('add', '--all') | Out-Null
    }
    if (-not (Test-PwGitStagedChanges)) {
        if ($comparison.Ahead -eq 0) {
            Write-Host '[INFO] No local changes or unpushed commits were found.'
            return
        }
        Write-Host "Local branch has $($comparison.Ahead) unpushed commit(s)."
        if (-not (Confirm-PwGitAction -Prompt "Push existing commits to ${upstream}?")) {
            Write-Host '[INFO] Push cancelled.'
            return
        }
        Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('push'))
        Write-Host '[ OK ] Existing local commits were pushed.'
        return
    }
    $message = Read-PwGitCommitMessage
    Write-Host "Branch         : $(Get-PwGitBranch)"
    Write-Host "Upstream       : $upstream"
    Write-Host "Commit message : $message"
    Write-Host ''
    Write-PwGitStagedSummary
    if (-not (Confirm-PwGitAction -Prompt 'Commit and push these changes?')) {
        Write-Host '[INFO] Push cancelled. Staged changes were left unchanged.'
        return
    }
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('commit', '-m', $message))
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('push'))
    Write-Host '[ OK ] Commit and push completed.'
}

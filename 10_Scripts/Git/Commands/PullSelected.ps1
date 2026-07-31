<#
.SYNOPSIS
    Restores selected files from the current upstream branch.
.DESCRIPTION
    Fetches the upstream branch, lists files changed upstream since the merge
    base, and restores explicitly selected files without advancing local commit
    history.
#>
Set-StrictMode -Version Latest
function Get-PwGitUpstreamChangedFiles {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Upstream)
    $mergeBase = Get-PwGitFirstOutputLine -InputObject @(Invoke-PwGitNative -Arguments @('merge-base', 'HEAD', $Upstream))
    if ([string]::IsNullOrWhiteSpace($mergeBase)) {
        throw "Could not determine the merge base between HEAD and $Upstream."
    }
    @(
        foreach ($line in @(Invoke-PwGitNative -Arguments @('diff', '--name-status', $mergeBase, $Upstream, '--'))) {
            $text = [string]$line
            if ([string]::IsNullOrWhiteSpace($text)) {
                continue
            }
            $parts = @($text -split "`t")
            if ($parts.Count -lt 2) {
                throw "Unexpected upstream change record: '$text'."
            }
            $status = [string]$parts[0]
            $path = if ($status -match '^[RC]' -and $parts.Count -ge 3) { [string]$parts[2] } else { [string]$parts[1] }
            [pscustomobject]@{ Status = $status; Path = $path }
        }
    )
}
function Invoke-PwGitPullSelected {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'Pull Selected Files'
    Assert-PwGitWritableState
    if (-not (Test-PwGitRemote)) {
        throw 'No origin remote configured.'
    }
    $upstream = Assert-PwGitUpstream
    Write-Host "Refreshing $upstream before file selection."
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('fetch', '--prune'))
    $comparison = Get-PwGitAheadBehind -Upstream $upstream
    Write-Host "Local branch is $($comparison.Ahead) commit(s) ahead and $($comparison.Behind) commit(s) behind $upstream."
    Write-Host ''
    [object[]]$availableItems = @(Get-PwGitUpstreamChangedFiles -Upstream $upstream)
    if ($availableItems.Count -eq 0) {
        Write-Host '[ OK ] The upstream branch introduces no selectable file changes.'
        return
    }
    [string[]]$requestedPaths = @(
        @($Arguments) |
            ForEach-Object { ([string]$_).Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    [string[]]$selectedPaths = @(
        if ($requestedPaths.Count -gt 0) {
            [string[]]$availablePaths = @($availableItems | ForEach-Object { [string]$_.Path })
            foreach ($path in $requestedPaths) {
                if ($availablePaths -notcontains $path) {
                    throw "'$path' is not among the changes introduced by $upstream."
                }
                $path
            }
        }
        else {
            Select-PwGitItems -Items $availableItems | ForEach-Object { [string]$_.Path }
        }
    )
    if ($selectedPaths.Count -eq 0) {
        Write-Host '[INFO] No files were selected.'
        return
    }
    [object[]]$localItems = @(Get-PwGitSelectableFiles)
    [object[]]$overwrittenChanges = @($localItems | Where-Object { $selectedPaths -contains [string]$_.Path })
    Write-Host ''
    Write-Host "Selected files will be restored from ${upstream}:"
    $selectedPaths | ForEach-Object { Write-Host "  $_" }
    if ($overwrittenChanges.Count -gt 0) {
        Write-Host ''
        Write-Warning 'The following selected files contain local changes that will be overwritten:'
        $overwrittenChanges | ForEach-Object { Write-Host "  $($_.Raw)" }
    }
    Write-Host ''
    Write-Warning 'This updates only the selected files. It does not merge or advance the current branch.'
    Write-Warning 'The selected upstream versions will be placed in both the index and working tree.'
    if (-not (Confirm-PwGitAction -Prompt "Replace the selected files with their versions from ${upstream}?")) {
        Write-Host '[INFO] Pull selected files cancelled. No files were changed.'
        return
    }
    $restoreArguments = @('restore', "--source=$upstream", '--staged', '--worktree', '--') + @($selectedPaths)
    Invoke-PwGitNative -Arguments $restoreArguments | Out-Null
    Write-Host '[ OK ] Selected files were updated from the upstream branch.'
    Write-Host '[INFO] The branch commit history was not changed.'
}

<#
.SYNOPSIS
    Reviews staged changes before commit.
#>
Set-StrictMode -Version Latest
function Invoke-PwGitReviewStaged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'Review Staged Changes'
    $staged = @(Invoke-PwGitNative -Arguments @('diff', '--cached', '--name-only'))
    if ($staged.Count -eq 0) {
        Write-Host '[INFO] No staged changes found.'
        return
    }
    Write-Host 'Staged files:'
    foreach ($file in $staged) {
        Write-Host "  $file"
    }
    Write-Host ''
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('diff', '--cached'))
}

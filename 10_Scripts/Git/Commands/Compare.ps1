Set-StrictMode -Version Latest

function Invoke-PwGitCompare {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context,

        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Local and Repository Comparison'

    Invoke-PwGitNative -Arguments @('fetch', '--prune') | ForEach-Object {
        if (-not [string]::IsNullOrWhiteSpace($_)) {
            Write-Host $_
        }
    }

    $branch = Get-PwGitBranch
    $upstream = Assert-PwGitUpstream
    $comparison = Get-PwGitAheadBehind -Upstream $upstream

    Write-Host "Local branch : $branch"
    Write-Host "Repo branch  : $upstream"
    Write-Host "Ahead        : $($comparison.Ahead) commit(s)"
    Write-Host "Behind       : $($comparison.Behind) commit(s)"
    Write-Host ''

    $status = Get-PwGitStatusLines
    if ($status.Count -eq 0) {
        Write-Host '[ OK ] No uncommitted local changes.'
    }
    else {
        Write-Host 'Uncommitted local changes:'
        $status | ForEach-Object { Write-Host "  $_" }
    }

    if ($comparison.Ahead -gt 0) {
        Write-Host ''
        Write-Host 'Commits only in local:'
        Invoke-PwGitNative -Arguments @('log', '--oneline', "$upstream..HEAD") |
            ForEach-Object { Write-Host "  $_" }
    }

    if ($comparison.Behind -gt 0) {
        Write-Host ''
        Write-Host 'Commits only in repo:'
        Invoke-PwGitNative -Arguments @('log', '--oneline', "HEAD..$upstream") |
            ForEach-Object { Write-Host "  $_" }
    }
}

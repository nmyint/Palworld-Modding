Set-StrictMode -Version Latest

function Invoke-PwGitStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context,

        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Repository Status'

    $branch = Get-PwGitBranch
    $upstream = Get-PwGitUpstream
    $status = Get-PwGitStatusLines

    Write-Host "Repository : $($Context.WorkshopRoot)"
    Write-Host "Branch     : $branch"
    Write-Host "Upstream   : $(if ($upstream) { $upstream } else { '<not configured>' })"
    Write-Host ''

    if ($status.Count -eq 0) {
        Write-Host '[ OK ] Working tree is clean.'
        return
    }

    Write-Host 'Changes:'
    $status | ForEach-Object { Write-Host "  $_" }
}

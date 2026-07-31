<#
.SYNOPSIS
    Fetches repository updates without modifying the working tree.
#>
Set-StrictMode -Version Latest
function Invoke-PwGitFetch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'Fetch Repository Updates'
    Assert-PwGitWritableState
    Invoke-PwGitNative -Arguments @('fetch','--prune') | Out-Null
    $upstream = Assert-PwGitUpstream
    $state = Get-PwGitAheadBehind -Upstream $upstream
    Write-Host '[ OK ] Fetch complete.'
    Write-Host "Behind: $($state.Behind) commit(s)"
    Write-Host "Ahead : $($state.Ahead) commit(s)"
}

Set-StrictMode -Version Latest

function Invoke-PwGitPull {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context,

        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Pull from Repository'

    if (-not (Test-PwGitClean)) {
        throw 'Pull cancelled because the local working tree contains changes.'
    }

    $upstream = Assert-PwGitUpstream
    Write-Host "Pulling from $upstream using fast-forward only."

    Invoke-PwGitNative -Arguments @('pull', '--ff-only') |
        ForEach-Object { Write-Host $_ }

    Write-Host '[ OK ] Pull completed.'
}

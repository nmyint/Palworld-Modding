Set-StrictMode -Version Latest

function Invoke-PwGitPull {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Context,
        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Pull from Repository'

    Assert-PwGitWritableState

    if (-not (Test-PwGitRemote)) {
        throw 'No origin remote configured.'
    }

    if (-not (Test-PwGitUpstream)) {
        throw 'Current branch has no upstream configured.'
    }

    if (-not (Test-PwGitClean)) {
        throw 'Pull cancelled because the local working tree contains changes.'
    }

    if (Test-PwGitDiverged) {
        throw 'Branches have diverged. Rebase before pulling.'
    }

    Invoke-PwGitNative -Arguments @('pull', '--ff-only') |
        ForEach-Object { Write-Host $_ }

    Write-Host '[ OK ] Pull completed.'
}

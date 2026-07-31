Set-StrictMode -Version Latest

function Invoke-PwGitCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context,
        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'pw-git Health Check'

    $gitVersion = Invoke-PwGitNative -Arguments @('--version') -AllowFailure -PassThru
    $branch = Get-PwGitBranch
    $upstream = Get-PwGitUpstream
    $state = Get-PwGitChangeState

    $checks = @(
        [pscustomobject]@{ Name='Workshop configuration'; Passed=$null -ne $Context.Config; Details=$Context.ConfigPath }
        [pscustomobject]@{ Name='Repository root'; Passed=Test-Path -LiteralPath (Join-Path $Context.WorkshopRoot '.git'); Details=$Context.WorkshopRoot }
        [pscustomobject]@{ Name='Git available'; Passed=$gitVersion.ExitCode -eq 0; Details=($gitVersion.Output -join ' ').Trim() }
        [pscustomobject]@{ Name='Current branch'; Passed=-not (Test-PwGitDetachedHead); Details=$(if ($branch) { $branch } else { 'Detached HEAD' }) }
        [pscustomobject]@{ Name='Origin remote'; Passed=Test-PwGitRemote; Details=$(if (Test-PwGitRemote) { 'Configured' } else { 'Missing' }) }
        [pscustomobject]@{ Name='Upstream branch'; Passed=Test-PwGitUpstream; Details=$(if ($upstream) { $upstream } else { 'Missing' }) }
        [pscustomobject]@{ Name='Merge conflicts'; Passed=-not (Test-PwGitConflicts); Details=$(if (Test-PwGitConflicts) { 'Present' } else { 'None' }) }
    )

    foreach ($check in $checks) {
        $label = if ($check.Passed) { '[ OK ]' } else { '[FAIL]' }
        Write-Host ('{0} {1}: {2}' -f $label, $check.Name, $check.Details)
    }

    Write-Host ''
    Write-Host 'Change state:'
    Write-Host "  Staged   : $($state.Staged)"
    Write-Host "  Unstaged : $($state.Unstaged)"
    Write-Host "  Conflicts: $($state.Conflicts)"

    if (Test-PwGitMixedChanges) {
        Write-Host '[WARN] Mixed staged and unstaged changes detected.'
    }

    if (Test-PwGitDiverged) {
        Write-Host '[WARN] Branches have diverged. Rebase recommended.'
    }
}

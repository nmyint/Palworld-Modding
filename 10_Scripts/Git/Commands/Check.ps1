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
    $origin = Invoke-PwGitNative -Arguments @('remote', 'get-url', 'origin') -AllowFailure -PassThru
    $branch = Get-PwGitBranch
    $upstream = Get-PwGitUpstream

    $checks = @(
        [pscustomobject]@{
            Name = 'Workshop configuration'
            Passed = $null -ne $Context.Config
            Details = $Context.ConfigPath
        }
        [pscustomobject]@{
            Name = 'Repository root'
            Passed = Test-Path -LiteralPath (Join-Path $Context.WorkshopRoot '.git')
            Details = $Context.WorkshopRoot
        }
        [pscustomobject]@{
            Name = 'Git available'
            Passed = $gitVersion.ExitCode -eq 0
            Details = ($gitVersion.Output -join ' ').Trim()
        }
        [pscustomobject]@{
            Name = 'Current branch'
            Passed = -not [string]::IsNullOrWhiteSpace($branch)
            Details = $(if ($branch) { $branch } else { 'Detached HEAD or unavailable' })
        }
        [pscustomobject]@{
            Name = 'Origin remote'
            Passed = $origin.ExitCode -eq 0
            Details = $(if ($origin.ExitCode -eq 0) { ($origin.Output -join ' ').Trim() } else { 'Not configured' })
        }
        [pscustomobject]@{
            Name = 'Upstream branch'
            Passed = -not [string]::IsNullOrWhiteSpace($upstream)
            Details = $(if ($upstream) { $upstream } else { 'Not configured' })
        }
    )

    foreach ($check in $checks) {
        $label = if ($check.Passed) { '[ OK ]' } else { '[FAIL]' }
        Write-Host ('{0} {1}: {2}' -f $label, $check.Name, $check.Details)
    }

    Write-Host ''
    $status = Get-PwGitStatusLines
    if ($status.Count -eq 0) {
        Write-Host '[ OK ] Working tree is clean.'
    }
    else {
        Write-Host '[INFO] Working tree contains changes:'
        $status | ForEach-Object { Write-Host "  $_" }
    }

    if ($checks.Passed -contains $false) {
        throw 'One or more pw-git health checks failed.'
    }
}

<#
.SYNOPSIS
    Shared helpers for pw-git command modules.
#>

Set-StrictMode -Version Latest

function Invoke-PwGitNative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [switch]$AllowFailure,
        [switch]$PassThru
    )

    $output = & git @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $message = ($output | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "Git command failed with exit code $exitCode."
        }

        throw "git $($Arguments -join ' ') failed.`n$message"
    }

    if ($PassThru) {
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output   = @($output)
        }
    }

    @($output)
}

function Get-PwGitBranch {
    [CmdletBinding()]
    param()

    $value = Invoke-PwGitNative -Arguments @('branch', '--show-current')
    ($value | Select-Object -First 1).ToString().Trim()
}

function Get-PwGitUpstream {
    [CmdletBinding()]
    param()

    $result = Invoke-PwGitNative -Arguments @(
        'rev-parse',
        '--abbrev-ref',
        '--symbolic-full-name',
        '@{upstream}'
    ) -AllowFailure -PassThru

    if ($result.ExitCode -ne 0) {
        return $null
    }

    ($result.Output | Select-Object -First 1).ToString().Trim()
}

function Get-PwGitStatusLines {
    [CmdletBinding()]
    param()

    @(Invoke-PwGitNative -Arguments @('status', '--short'))
}

function Test-PwGitClean {
    [CmdletBinding()]
    param()

    (Get-PwGitStatusLines).Count -eq 0
}

function Test-PwGitStagedChanges {
    [CmdletBinding()]
    param()

    $result = Invoke-PwGitNative -Arguments @('diff', '--cached', '--quiet') -AllowFailure -PassThru
    $result.ExitCode -eq 1
}

function Get-PwGitAheadBehind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Upstream
    )

    $value = Invoke-PwGitNative -Arguments @(
        'rev-list',
        '--left-right',
        '--count',
        "$Upstream...HEAD"
    )

    $parts = (($value | Select-Object -First 1).ToString().Trim() -split '\s+')

    [pscustomobject]@{
        Behind = [int]$parts[0]
        Ahead  = [int]$parts[1]
    }
}

function Confirm-PwGitAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    $answer = Read-Host "$Prompt [y/N]"
    $answer -match '^(?i:y|yes)$'
}

function Write-PwGitSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ''
    Write-Host ('=' * 72)
    Write-Host ('  {0}' -f $Title)
    Write-Host ('=' * 72)
}

function Assert-PwGitUpstream {
    [CmdletBinding()]
    param()

    $upstream = Get-PwGitUpstream
    if ([string]::IsNullOrWhiteSpace($upstream)) {
        throw "Branch '$(Get-PwGitBranch)' has no upstream branch configured."
    }

    $upstream
}

function Read-PwGitCommitMessage {
    [CmdletBinding()]
    param()

    while ($true) {
        $message = Read-Host 'Commit message'
        if (-not [string]::IsNullOrWhiteSpace($message)) {
            return $message.Trim()
        }

        Write-Warning 'A commit message is required.'
    }
}

<#
.SYNOPSIS
    Shared helpers for pw-git command modules.
#>

Set-StrictMode -Version Latest

function Stop-PwGitUx {
    [CmdletBinding()]
    param()

    throw [System.OperationCanceledException]::new('PWGIT_QUIT')
}

function Test-PwGitQuitInput {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    -not [string]::IsNullOrWhiteSpace($Value) -and
        $Value.Trim().Equals('Q', [System.StringComparison]::OrdinalIgnoreCase)
}

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

    @(Get-PwGitStatusLines).Count -eq 0
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

    $answer = Read-Host "$Prompt [y/N/Q]"
    if (Test-PwGitQuitInput -Value $answer) {
        Stop-PwGitUx
    }

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
        $message = Read-Host 'Commit message [Q to quit]'
        if (Test-PwGitQuitInput -Value $message) {
            Stop-PwGitUx
        }

        if (-not [string]::IsNullOrWhiteSpace($message)) {
            return $message.Trim()
        }

        Write-Warning 'A commit message is required.'
    }
}

function Get-PwGitSelectableFiles {
    [CmdletBinding()]
    param()

    $items = [System.Collections.Generic.List[object]]::new()

    foreach ($line in @(Get-PwGitStatusLines)) {
        $text = [string]$line
        if ([string]::IsNullOrWhiteSpace($text) -or $text.Length -lt 4) {
            continue
        }

        $path = $text.Substring(3).Trim()
        if ($path -match ' -> ') {
            $path = ($path -split ' -> ', 2)[1]
        }

        $items.Add([pscustomobject]@{
            Status = $text.Substring(0, 2)
            Path   = $path
        })
    }

    @($items)
}

function Select-PwGitFiles {
    [CmdletBinding()]
    param()

    $items = @(Get-PwGitSelectableFiles)
    if ($items.Count -eq 0) {
        return @()
    }

    Write-Host 'Select files by number. Use commas or ranges (example: 1,3-5).'
    Write-Host 'Enter Q to quit pw-git.'
    Write-Host ''

    for ($index = 0; $index -lt $items.Count; $index++) {
        Write-Host ('{0,3}. [{1}] {2}' -f ($index + 1), $items[$index].Status, $items[$index].Path)
    }

    Write-Host ''
    $selection = Read-Host 'Selection'
    if (Test-PwGitQuitInput -Value $selection) {
        Stop-PwGitUx
    }

    if ([string]::IsNullOrWhiteSpace($selection)) {
        return @()
    }

    $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new()

    foreach ($token in ($selection -split ',')) {
        $trimmedToken = $token.Trim()

        if ($trimmedToken -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]

            if ($start -gt $end) {
                $temporary = $start
                $start = $end
                $end = $temporary
            }

            foreach ($number in $start..$end) {
                if ($number -ge 1 -and $number -le $items.Count) {
                    [void]$selectedIndexes.Add($number - 1)
                }
            }

            continue
        }

        if ($trimmedToken -match '^\d+$') {
            $number = [int]$trimmedToken
            if ($number -ge 1 -and $number -le $items.Count) {
                [void]$selectedIndexes.Add($number - 1)
            }

            continue
        }

        throw "Invalid file selection token: '$trimmedToken'."
    }

    @(
        $selectedIndexes |
            Sort-Object |
            ForEach-Object { $items[$_].Path }
    )
}

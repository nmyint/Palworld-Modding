<#
.SYNOPSIS
    Shared runtime and UX helpers for Pw-Git.
#>
Set-StrictMode -Version Latest
function Stop-PwGitUx {
    [CmdletBinding()]
    param()
    throw [System.OperationCanceledException]::new('PWGIT_QUIT')
}
function Stop-PwGitMenu {
    [CmdletBinding()]
    param()
    throw [System.OperationCanceledException]::new('PWGIT_BACK')
}
function Test-PwGitQuitInput {
    [CmdletBinding()]
    param([AllowNull()][string]$Value)
    -not [string]::IsNullOrWhiteSpace($Value) -and $Value.Trim().Equals('Q', [System.StringComparison]::OrdinalIgnoreCase)
}
function Test-PwGitBackInput {
    [CmdletBinding()]
    param([AllowNull()][string]$Value)
    -not [string]::IsNullOrWhiteSpace($Value) -and $Value.Trim().Equals('B', [System.StringComparison]::OrdinalIgnoreCase)
}
function Get-PwGitFirstOutputLine {
    [CmdletBinding()]
    param([AllowNull()][object[]]$InputObject)
    $line = @($InputObject) | Select-Object -First 1
    if ($null -eq $line) {
        return ''
    }
    ([string]$line).Trim()
}
function Invoke-PwGitNative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure,
        [switch]$PassThru
    )
    [object[]]$output = @(& git @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $message = (($output | ForEach-Object { [string]$_ }) | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "Git command failed with exit code $exitCode."
        }
        throw "git $($Arguments -join ' ') failed.`n$message"
    }
    if ($PassThru) {
        return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
    }
    $output
}
function Write-PwGitOutput {
    [CmdletBinding()]
    param([AllowNull()][object[]]$InputObject)
    foreach ($item in @($InputObject)) {
        $text = [string]$item
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            Write-Host $text
        }
    }
}
function Get-PwGitBranch {
    [CmdletBinding()]
    param()
    Get-PwGitFirstOutputLine -InputObject @(Invoke-PwGitNative -Arguments @('branch', '--show-current'))
}
function Get-PwGitUpstream {
    [CmdletBinding()]
    param()
    $result = Invoke-PwGitNative -Arguments @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}') -AllowFailure -PassThru
    if ($result.ExitCode -ne 0) {
        return $null
    }
    $upstream = Get-PwGitFirstOutputLine -InputObject $result.Output
    if ([string]::IsNullOrWhiteSpace($upstream)) {
        return $null
    }
    $upstream
}
function Get-PwGitOriginUrl {
    [CmdletBinding()]
    param()
    $result = Invoke-PwGitNative -Arguments @('remote', 'get-url', 'origin') -AllowFailure -PassThru
    if ($result.ExitCode -ne 0) {
        return $null
    }
    $url = Get-PwGitFirstOutputLine -InputObject $result.Output
    if ([string]::IsNullOrWhiteSpace($url)) {
        return $null
    }
    $url
}
function Get-PwGitStatusLines {
    [CmdletBinding()]
    param()
    @(Invoke-PwGitNative -Arguments @('status', '--short', '--untracked-files=all'))
}
function ConvertFrom-PwGitStatusLine {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line) -or $Line.Length -lt 4) {
        return $null
    }
    $path = $Line.Substring(3).Trim()
    if ($path -match ' -> ') {
        $path = ($path -split ' -> ', 2)[1]
    }
    [pscustomobject]@{ Status = $Line.Substring(0, 2); Path = $path; Raw = $Line }
}
function Get-PwGitSelectableFiles {
    [CmdletBinding()]
    param()
    @(
        foreach ($line in @(Get-PwGitStatusLines)) {
            $item = ConvertFrom-PwGitStatusLine -Line ([string]$line)
            if ($null -ne $item) {
                $item
            }
        }
    )
}
function Test-PwGitClean {
    [CmdletBinding()]
    param()
    @(Get-PwGitStatusLines).Count -eq 0
}
function Test-PwGitStagedChanges {
    [CmdletBinding()]
    param()
    $result = Invoke-PwGitNative -Arguments @('diff', '--cached', '--quiet', '--') -AllowFailure -PassThru
    switch ($result.ExitCode) {
        0 { return $false }
        1 { return $true }
        default {
            $message = (($result.Output | ForEach-Object { [string]$_ }) | Out-String).Trim()
            throw ("Unable to determine staged-change state. git diff exited with code $($result.ExitCode). $message").Trim()
        }
    }
}
function Get-PwGitStagedPaths {
    [CmdletBinding()]
    param()
    [string[]]@(
        Invoke-PwGitNative -Arguments @('diff', '--cached', '--name-only', '--') |
            ForEach-Object { ([string]$_).Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}
function Get-PwGitAheadBehind {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Upstream)
    $line = Get-PwGitFirstOutputLine -InputObject @(Invoke-PwGitNative -Arguments @('rev-list', '--left-right', '--count', "$Upstream...HEAD"))
    $parts = @($line -split '\s+')
    $behind = 0
    $ahead = 0
    if ($parts.Count -ne 2 -or -not [int]::TryParse($parts[0], [ref]$behind) -or -not [int]::TryParse($parts[1], [ref]$ahead)) {
        throw "Unexpected ahead/behind output for '$Upstream': '$line'."
    }
    [pscustomobject]@{ Behind = $behind; Ahead = $ahead }
}
function Confirm-PwGitAction {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)
    $answer = Read-Host "$Prompt [Y/N, Enter cancel, B menu, Q quit]"
    if (Test-PwGitQuitInput -Value $answer) {
        Stop-PwGitUx
    }
    if (Test-PwGitBackInput -Value $answer) {
        Stop-PwGitMenu
    }
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $false
    }
    $answer.Trim().Equals('Y', [System.StringComparison]::OrdinalIgnoreCase) -or $answer.Trim().Equals('YES', [System.StringComparison]::OrdinalIgnoreCase)
}
function Write-PwGitSection {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ''
    Write-Host ('=' * 72)
    Write-Host ('  {0}' -f $Title)
    Write-Host ('=' * 72)
}
function Write-PwGitStagedSummary {
    [CmdletBinding()]
    param()
    Write-Host 'Staged changes:'
    $summary = @(Invoke-PwGitNative -Arguments @('diff', '--cached', '--stat', '--'))
    if ($summary.Count -eq 0) {
        Write-Host '  <none>'
        return
    }
    $summary | ForEach-Object { Write-Host "  $_" }
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
    $message = Read-Host 'Commit message [Enter/B cancel, Q quit]'
    if (Test-PwGitQuitInput -Value $message) {
        Stop-PwGitUx
    }
    if ([string]::IsNullOrWhiteSpace($message) -or (Test-PwGitBackInput -Value $message)) {
        Stop-PwGitMenu
    }
    $message.Trim()
}
function ConvertFrom-PwGitSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Selection,
        [Parameter(Mandatory)][ValidateRange(1, 2147483647)][int]$Maximum
    )
    $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($token in ($Selection -split ',')) {
        $trimmedToken = $token.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmedToken)) {
            throw 'File selections cannot contain empty entries.'
        }
        if ($trimmedToken -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            if ($start -gt $end) {
                $temporary = $start
                $start = $end
                $end = $temporary
            }
            foreach ($number in $start..$end) {
                if ($number -lt 1 -or $number -gt $Maximum) {
                    throw "Selection '$number' is outside the available range 1-$Maximum."
                }
                [void]$selectedIndexes.Add($number - 1)
            }
            continue
        }
        if ($trimmedToken -match '^\d+$') {
            $number = [int]$trimmedToken
            if ($number -lt 1 -or $number -gt $Maximum) {
                throw "Selection '$number' is outside the available range 1-$Maximum."
            }
            [void]$selectedIndexes.Add($number - 1)
            continue
        }
        throw "Invalid file selection token: '$trimmedToken'."
    }
    @($selectedIndexes | Sort-Object)
}
function Select-PwGitItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items,
        [string]$StatusProperty = 'Status',
        [string]$PathProperty = 'Path'
    )
    if (@($Items).Count -eq 0) {
        return @()
    }
    Write-Host 'Select files by number. Use commas or ranges (example: 1,3-5).'
    Write-Host 'Press Enter or B to return to the menu. Enter Q to quit Pw-Git.'
    Write-Host ''
    for ($index = 0; $index -lt $Items.Count; $index++) {
        Write-Host ('{0,3}. [{1}] {2}' -f ($index + 1), $Items[$index].$StatusProperty, $Items[$index].$PathProperty)
    }
    Write-Host ''
    $selection = Read-Host 'Selection'
    if (Test-PwGitQuitInput -Value $selection) {
        Stop-PwGitUx
    }
    if ([string]::IsNullOrWhiteSpace($selection) -or (Test-PwGitBackInput -Value $selection)) {
        Stop-PwGitMenu
    }
    [int[]]$indexes = @(ConvertFrom-PwGitSelection -Selection $selection -Maximum $Items.Count)
    @($indexes | ForEach-Object { $Items[$_] })
}
function Select-PwGitFiles {
    [CmdletBinding()]
    param()
    [object[]]$items = @(Get-PwGitSelectableFiles)
    if ($items.Count -eq 0) {
        return @()
    }
    [string[]]@(
        Select-PwGitItems -Items $items |
            ForEach-Object { [string]$_.Path }
    )
}

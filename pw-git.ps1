<#
.SYNOPSIS
    Interactive Git helper for the Palworld Modding Workshop.

.DESCRIPTION
    Provides safe, readable Git workflows for the local Palworld-Modding
    working copy. The script supports repository health checks, status and
    comparison views, pulling, pushing all changes, and pushing selected files.

    Any workflow that creates a commit displays a summary and requires explicit
    confirmation before the commit and push are performed.

.NOTES
    Project: pw-git
    Repository: nmyint/Palworld-Modding
    Requires: Git available on PATH
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Menu', 'Check', 'Compare', 'Pull', 'Push', 'PushSelected')]
    [string]$Command = 'Menu',

    [Parameter()]
    [string]$RepositoryPath = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-PwGitHeading {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    Write-Host ''
    Write-Host ('=' * 72)
    Write-Host ('  {0}' -f $Text)
    Write-Host ('=' * 72)
}

function Write-PwGitInfo {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ('[INFO] {0}' -f $Message)
}

function Write-PwGitSuccess {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ('[ OK ] {0}' -f $Message)
}

function Write-PwGitWarning {
    param([Parameter(Mandatory)][string]$Message)
    Write-Warning $Message
}

function Invoke-PwGit {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter()]
        [switch]$AllowFailure,

        [Parameter()]
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

    return @($output)
}

function Resolve-PwGitRepository {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path

    Push-Location $resolvedPath
    try {
        $result = Invoke-PwGit -Arguments @('rev-parse', '--show-toplevel') -AllowFailure -PassThru
        if ($result.ExitCode -ne 0) {
            throw "'$resolvedPath' is not inside a Git repository."
        }

        return ($result.Output | Select-Object -First 1).ToString().Trim()
    }
    finally {
        Pop-Location
    }
}

function Get-PwGitCurrentBranch {
    $branch = Invoke-PwGit -Arguments @('branch', '--show-current')
    return ($branch | Select-Object -First 1).ToString().Trim()
}

function Get-PwGitUpstream {
    $result = Invoke-PwGit -Arguments @(
        'rev-parse',
        '--abbrev-ref',
        '--symbolic-full-name',
        '@{upstream}'
    ) -AllowFailure -PassThru

    if ($result.ExitCode -ne 0) {
        return $null
    }

    return ($result.Output | Select-Object -First 1).ToString().Trim()
}

function Get-PwGitStatusLines {
    return @(Invoke-PwGit -Arguments @('status', '--short'))
}

function Test-PwGitHasChanges {
    return (Get-PwGitStatusLines).Count -gt 0
}

function Test-PwGitHasStagedChanges {
    $result = Invoke-PwGit -Arguments @('diff', '--cached', '--quiet') -AllowFailure -PassThru
    return $result.ExitCode -eq 1
}

function Test-PwGitWorkingTreeClean {
    return -not (Test-PwGitHasChanges)
}

function Get-PwGitAheadBehind {
    param(
        [Parameter(Mandatory)]
        [string]$Upstream
    )

    $result = Invoke-PwGit -Arguments @(
        'rev-list',
        '--left-right',
        '--count',
        "$Upstream...HEAD"
    )

    $parts = (($result | Select-Object -First 1).ToString().Trim() -split '\s+')
    return [pscustomobject]@{
        Behind = [int]$parts[0]
        Ahead  = [int]$parts[1]
    }
}

function Confirm-PwGitAction {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    $answer = Read-Host "$Prompt [y/N]"
    return $answer -match '^(?i:y|yes)$'
}

function Show-PwGitStatus {
    Write-PwGitHeading 'Repository Status'

    $branch = Get-PwGitCurrentBranch
    $upstream = Get-PwGitUpstream
    $statusLines = Get-PwGitStatusLines

    Write-Host "Repository : $script:PwGitRepositoryRoot"
    Write-Host "Branch     : $branch"
    Write-Host "Upstream   : $(if ($upstream) { $upstream } else { '<not configured>' })"
    Write-Host ''

    if ($statusLines.Count -eq 0) {
        Write-PwGitSuccess 'Working tree is clean.'
        return
    }

    Write-Host 'Changes:'
    $statusLines | ForEach-Object { Write-Host "  $_" }
}

function Test-PwGitHealth {
    Write-PwGitHeading 'pw-git Health Check'

    $checks = [System.Collections.Generic.List[object]]::new()

    $gitVersionResult = Invoke-PwGit -Arguments @('--version') -AllowFailure -PassThru
    $checks.Add([pscustomobject]@{
        Check   = 'Git available'
        Passed  = $gitVersionResult.ExitCode -eq 0
        Details = ($gitVersionResult.Output -join ' ').Trim()
    })

    $checks.Add([pscustomobject]@{
        Check   = 'Repository detected'
        Passed  = Test-Path -LiteralPath (Join-Path $script:PwGitRepositoryRoot '.git')
        Details = $script:PwGitRepositoryRoot
    })

    $branch = Get-PwGitCurrentBranch
    $checks.Add([pscustomobject]@{
        Check   = 'Current branch'
        Passed  = -not [string]::IsNullOrWhiteSpace($branch)
        Details = $(if ($branch) { $branch } else { 'Detached HEAD or unavailable' })
    })

    $remoteResult = Invoke-PwGit -Arguments @('remote', 'get-url', 'origin') -AllowFailure -PassThru
    $checks.Add([pscustomobject]@{
        Check   = 'Origin remote'
        Passed  = $remoteResult.ExitCode -eq 0
        Details = $(if ($remoteResult.ExitCode -eq 0) { ($remoteResult.Output -join ' ').Trim() } else { 'Not configured' })
    })

    $upstream = Get-PwGitUpstream
    $checks.Add([pscustomobject]@{
        Check   = 'Upstream branch'
        Passed  = -not [string]::IsNullOrWhiteSpace($upstream)
        Details = $(if ($upstream) { $upstream } else { 'Not configured' })
    })

    foreach ($check in $checks) {
        $label = if ($check.Passed) { '[ OK ]' } else { '[FAIL]' }
        Write-Host ('{0} {1}: {2}' -f $label, $check.Check, $check.Details)
    }

    Write-Host ''
    Show-PwGitStatus

    return -not ($checks.Passed -contains $false)
}

function Show-PwGitCompare {
    Write-PwGitHeading 'Local and Repository Comparison'

    $branch = Get-PwGitCurrentBranch
    $upstream = Get-PwGitUpstream

    Write-PwGitInfo 'Refreshing remote references.'
    Invoke-PwGit -Arguments @('fetch', '--prune') | ForEach-Object {
        if ($_ -and $_.ToString().Trim()) {
            Write-Host $_
        }
    }

    if (-not $upstream) {
        Write-PwGitWarning "Branch '$branch' has no upstream branch configured."
        Show-PwGitStatus
        return
    }

    $comparison = Get-PwGitAheadBehind -Upstream $upstream

    Write-Host "Local branch : $branch"
    Write-Host "Repo branch  : $upstream"
    Write-Host "Ahead        : $($comparison.Ahead) commit(s)"
    Write-Host "Behind       : $($comparison.Behind) commit(s)"
    Write-Host ''

    $statusLines = Get-PwGitStatusLines
    if ($statusLines.Count -gt 0) {
        Write-Host 'Uncommitted local changes:'
        $statusLines | ForEach-Object { Write-Host "  $_" }
    }
    else {
        Write-PwGitSuccess 'No uncommitted local changes.'
    }

    if ($comparison.Ahead -gt 0) {
        Write-Host ''
        Write-Host 'Commits only in local:'
        Invoke-PwGit -Arguments @('log', '--oneline', "$upstream..HEAD") |
            ForEach-Object { Write-Host "  $_" }
    }

    if ($comparison.Behind -gt 0) {
        Write-Host ''
        Write-Host 'Commits only in repo:'
        Invoke-PwGit -Arguments @('log', '--oneline', "HEAD..$upstream") |
            ForEach-Object { Write-Host "  $_" }
    }
}

function Invoke-PwGitPull {
    Write-PwGitHeading 'Pull from Repository'

    if (-not (Test-PwGitWorkingTreeClean)) {
        Write-PwGitWarning 'Pull cancelled because the local working tree contains changes.'
        Show-PwGitStatus
        return
    }

    $upstream = Get-PwGitUpstream
    if (-not $upstream) {
        throw "The current branch has no upstream branch. Configure one before pulling."
    }

    Write-PwGitInfo "Pulling from $upstream using fast-forward only."
    Invoke-PwGit -Arguments @('pull', '--ff-only') | ForEach-Object { Write-Host $_ }
    Write-PwGitSuccess 'Pull completed.'
}

function Read-PwGitCommitMessage {
    while ($true) {
        $message = Read-Host 'Commit message'
        if (-not [string]::IsNullOrWhiteSpace($message)) {
            return $message.Trim()
        }

        Write-PwGitWarning 'A commit message is required.'
    }
}

function Show-PwGitCommitSummary {
    param(
        [Parameter(Mandatory)]
        [string]$CommitMessage
    )

    Write-PwGitHeading 'Commit and Push Summary'
    Write-Host "Branch         : $(Get-PwGitCurrentBranch)"
    Write-Host "Upstream       : $(Get-PwGitUpstream)"
    Write-Host "Commit message : $CommitMessage"
    Write-Host ''
    Write-Host 'Staged changes:'

    $summary = @(Invoke-PwGit -Arguments @('diff', '--cached', '--stat'))
    if ($summary.Count -eq 0) {
        Write-Host '  <none>'
    }
    else {
        $summary | ForEach-Object { Write-Host "  $_" }
    }

    Write-Host ''
    Invoke-PwGit -Arguments @('status', '--short') | ForEach-Object {
        Write-Host "  $_"
    }
}

function Invoke-PwGitCommitAndPush {
    param(
        [Parameter(Mandatory)]
        [string]$CommitMessage
    )

    if (-not (Test-PwGitHasStagedChanges)) {
        Write-PwGitWarning 'No staged changes were found. Nothing was committed.'
        return
    }

    Show-PwGitCommitSummary -CommitMessage $CommitMessage

    if (-not (Confirm-PwGitAction -Prompt 'Commit and push these staged changes?')) {
        Write-PwGitInfo 'Commit and push cancelled. Staged changes were left unchanged.'
        return
    }

    Invoke-PwGit -Arguments @('commit', '-m', $CommitMessage) |
        ForEach-Object { Write-Host $_ }

    $branch = Get-PwGitCurrentBranch
    $upstream = Get-PwGitUpstream

    if ($upstream) {
        Invoke-PwGit -Arguments @('push') | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-PwGitInfo "No upstream exists. Publishing branch '$branch' to origin."
        Invoke-PwGit -Arguments @('push', '--set-upstream', 'origin', $branch) |
            ForEach-Object { Write-Host $_ }
    }

    Write-PwGitSuccess 'Commit and push completed.'
}

function Invoke-PwGitPushAll {
    Write-PwGitHeading 'Push All Local Changes'

    if (-not (Test-PwGitHasChanges)) {
        Write-PwGitInfo 'No local changes were found.'
        return
    }

    Write-Host 'Changes to stage:'
    Get-PwGitStatusLines | ForEach-Object { Write-Host "  $_" }
    Write-Host ''

    if (-not (Confirm-PwGitAction -Prompt 'Stage all listed changes?')) {
        Write-PwGitInfo 'Push cancelled. No files were staged by pw-git.'
        return
    }

    Invoke-PwGit -Arguments @('add', '--all') | Out-Null
    $message = Read-PwGitCommitMessage
    Invoke-PwGitCommitAndPush -CommitMessage $message
}

function Get-PwGitSelectableFiles {
    $lines = Get-PwGitStatusLines
    $items = [System.Collections.Generic.List[object]]::new()

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }

        $path = $line.Substring(3).Trim()
        if ($path -match ' -> ') {
            $path = ($path -split ' -> ', 2)[1]
        }

        $items.Add([pscustomobject]@{
            Status = $line.Substring(0, 2)
            Path   = $path
        })
    }

    return @($items)
}

function Select-PwGitFiles {
    $items = @(Get-PwGitSelectableFiles)
    if ($items.Count -eq 0) {
        return @()
    }

    Write-Host 'Select files by number. Use commas or ranges (example: 1,3-5).'
    Write-Host ''

    for ($index = 0; $index -lt $items.Count; $index++) {
        Write-Host ('{0,3}. [{1}] {2}' -f ($index + 1), $items[$index].Status, $items[$index].Path)
    }

    Write-Host ''
    $selection = Read-Host 'Selection'
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

    return @(
        $selectedIndexes |
            Sort-Object |
            ForEach-Object { $items[$_].Path }
    )
}

function Invoke-PwGitPushSelected {
    Write-PwGitHeading 'Push Selected Files'

    if (-not (Test-PwGitHasChanges)) {
        Write-PwGitInfo 'No local changes were found.'
        return
    }

    $selectedFiles = @(Select-PwGitFiles)
    if ($selectedFiles.Count -eq 0) {
        Write-PwGitInfo 'No files were selected.'
        return
    }

    Write-Host ''
    Write-Host 'Selected files:'
    $selectedFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ''

    if (-not (Confirm-PwGitAction -Prompt 'Stage the selected files?')) {
        Write-PwGitInfo 'Selection cancelled. No files were staged by pw-git.'
        return
    }

    foreach ($file in $selectedFiles) {
        Invoke-PwGit -Arguments @('add', '--', $file) | Out-Null
    }

    $message = Read-PwGitCommitMessage
    Invoke-PwGitCommitAndPush -CommitMessage $message
}

function Show-PwGitMenu {
    while ($true) {
        Write-PwGitHeading 'pw-git'
        Write-Host '1. Check repository health'
        Write-Host '2. Compare local and repo'
        Write-Host '3. Pull from repo'
        Write-Host '4. Push all local changes'
        Write-Host '5. Push selected files'
        Write-Host '6. Show status'
        Write-Host '0. Exit'
        Write-Host ''

        $choice = Read-Host 'Choose an action'

        try {
            switch ($choice) {
                '1' { [void](Test-PwGitHealth) }
                '2' { Show-PwGitCompare }
                '3' { Invoke-PwGitPull }
                '4' { Invoke-PwGitPushAll }
                '5' { Invoke-PwGitPushSelected }
                '6' { Show-PwGitStatus }
                '0' { return }
                default { Write-PwGitWarning "Unknown menu choice: '$choice'." }
            }
        }
        catch {
            Write-Error $_
        }

        Write-Host ''
        [void](Read-Host 'Press Enter to continue')
    }
}

try {
    $script:PwGitRepositoryRoot = Resolve-PwGitRepository -Path $RepositoryPath
    Push-Location $script:PwGitRepositoryRoot

    switch ($Command) {
        'Menu'         { Show-PwGitMenu }
        'Check'        { [void](Test-PwGitHealth) }
        'Compare'      { Show-PwGitCompare }
        'Pull'         { Invoke-PwGitPull }
        'Push'         { Invoke-PwGitPushAll }
        'PushSelected' { Invoke-PwGitPushSelected }
    }
}
catch {
    Write-Error $_
    exit 1
}
finally {
    if ((Get-Location).Path -eq $script:PwGitRepositoryRoot) {
        Pop-Location
    }
}

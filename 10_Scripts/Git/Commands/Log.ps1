Set-StrictMode -Version Latest

function Invoke-PwGitLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context,

        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Repository History'

    $count = 15
    if ($Arguments.Count -gt 0) {
        $parsedCount = 0
        if (-not [int]::TryParse($Arguments[0], [ref]$parsedCount)) {
            throw "Log count must be an integer. Received: '$($Arguments[0])'."
        }

        if ($parsedCount -lt 1 -or $parsedCount -gt 100) {
            throw 'Log count must be between 1 and 100.'
        }

        $count = $parsedCount
    }

    Invoke-PwGitNative -Arguments @(
        'log',
        "-$count",
        '--date=short',
        '--pretty=format:%h  %ad  %an  %s'
    ) | ForEach-Object { Write-Host $_ }
}

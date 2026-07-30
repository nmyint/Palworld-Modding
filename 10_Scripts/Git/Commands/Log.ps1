Set-StrictMode -Version Latest

function Invoke-PwGitLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context,

        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Repository History'

    $argumentList = @($Arguments)
    $count = 15

    if ($argumentList.Count -gt 0) {
        $parsedCount = 0
        if (-not [int]::TryParse($argumentList[0], [ref]$parsedCount)) {
            throw "Log count must be an integer. Received: '$($argumentList[0])'."
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

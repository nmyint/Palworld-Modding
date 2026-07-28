<#
.SYNOPSIS
    JSON helper functions.
#>

Set-StrictMode -Version Latest

function Resolve-PwJsonPath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw [System.IO.FileNotFoundException]::new(
            "JSON file not found.",
            $Path
        )
    }

    (Resolve-Path -LiteralPath $Path).Path
}

function Read-PwJson {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $resolved = Resolve-PwJsonPath -Path $Path

    Get-Content -LiteralPath $resolved -Raw |
        ConvertFrom-Json
}

function Write-PwJson {

    [CmdletBinding(SupportsShouldProcess)]
    param(

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position = 0
        )]
        [object]$InputObject,

        [Parameter(
            Mandatory,
            Position = 1
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [ValidateRange(1,100)]
        [int]$Depth = 10
    )

    process {

        if ($PSCmdlet.ShouldProcess($Path,"Write JSON")) {

            $json = $InputObject |
                ConvertTo-Json -Depth $Depth

            Set-Content `
                -LiteralPath $Path `
                -Value $json `
                -Encoding utf8
        }

    }

}

function Test-PwJson {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {

        Read-PwJson -Path $Path | Out-Null
        $true

    }
    catch {

        $false

    }

}
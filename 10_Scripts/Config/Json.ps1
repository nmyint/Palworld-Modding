<#
.SYNOPSIS
    JSON helper functions.
#>

Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Resolves and validates the path to a JSON file.
.PARAMETER Path
    Path to an existing JSON file.
.OUTPUTS
    System.String containing the absolute file path.
#>
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

<#
.SYNOPSIS
    Reads and deserializes a JSON file.
.PARAMETER Path
    Path to an existing JSON file.
.OUTPUTS
    PSCustomObject containing the deserialized JSON data.
#>
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

<#
.SYNOPSIS
    Serializes an object and writes it to a JSON file.
.PARAMETER InputObject
    Object to serialize.
.PARAMETER Path
    Destination JSON file path.
.PARAMETER Depth
    Maximum serialization depth.
#>
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

<#
.SYNOPSIS
    Tests whether a file contains readable JSON.
.PARAMETER Path
    Path to the JSON file to test.
.OUTPUTS
    System.Boolean indicating whether the file can be read and deserialized.
#>
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

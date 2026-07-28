<#
.SYNOPSIS
    Workshop configuration management.
#>

Set-StrictMode -Version Latest

# Load dependency
if (-not (Get-Command Read-PwJson -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\Json.ps1"
}

function Get-PwWorkshopRoot {

    [CmdletBinding()]
    param()

    (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

}

function Get-PwWorkshopConfigPath {

    [CmdletBinding()]
    param()

    Join-Path `
        (Get-PwWorkshopRoot) `
        ".config\Workshop.json"

}

function Get-PwWorkshopConfig {

    [CmdletBinding()]
    param()

    Read-PwJson -Path (Get-PwWorkshopConfigPath)

}

function Save-PwWorkshopConfig {

    [CmdletBinding()]
    param(

        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [object]$Configuration

    )

    process {

        Write-PwJson `
            -InputObject $Configuration `
            -Path (Get-PwWorkshopConfigPath)

    }

}

function Test-PwWorkshopConfig {

    [CmdletBinding()]
    param()

    Test-PwJson -Path (Get-PwWorkshopConfigPath)

}
<#
.SYNOPSIS
    Workshop configuration management.
#>

Set-StrictMode -Version Latest

# Load the JSON helper when this file is dot-sourced independently.
if (-not (Get-Command Read-PwJson -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\Json.ps1"
}

<#
.SYNOPSIS
    Gets the absolute workshop root.
.OUTPUTS
    System.String containing the repository root path.
#>
function Get-PwWorkshopRoot {

    [CmdletBinding()]
    param()

    (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

}

<#
.SYNOPSIS
    Gets the workshop configuration file path.
.OUTPUTS
    System.String containing the path to Workshop.json.
#>
function Get-PwWorkshopConfigPath {

    [CmdletBinding()]
    param()

    Join-Path `
        (Get-PwWorkshopRoot) `
        ".config\Workshop.json"

}

<#
.SYNOPSIS
    Gets the deserialized workshop configuration.
.OUTPUTS
    PSCustomObject containing the Workshop.json configuration.
#>
function Get-PwWorkshopConfig {

    [CmdletBinding()]
    param()

    Read-PwJson -Path (Get-PwWorkshopConfigPath)

}

<#
.SYNOPSIS
    Saves the workshop configuration.
.PARAMETER Configuration
    Configuration object to serialize to Workshop.json.
#>
function Save-PwWorkshopConfig {

    [CmdletBinding(SupportsShouldProcess)]
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

<#
.SYNOPSIS
    Tests whether Workshop.json contains readable JSON.
.OUTPUTS
    System.Boolean indicating whether the configuration is valid JSON.
#>
function Test-PwWorkshopConfig {

    [CmdletBinding()]
    param()

    Test-PwJson -Path (Get-PwWorkshopConfigPath)

}

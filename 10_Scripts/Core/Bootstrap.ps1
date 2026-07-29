<#
.SYNOPSIS
    Initializes the Palworld Modding Workshop.
#>

Set-StrictMode -Version Latest

# Load required configuration helpers when this file is dot-sourced independently.
. "$PSScriptRoot\..\Config\Json.ps1"
. "$PSScriptRoot\..\Config\WorkshopConfig.ps1"

<#
.SYNOPSIS
    Initializes the workshop context.
.OUTPUTS
    PSCustomObject containing the workshop root, configuration, and start time.
#>
function Initialize-PwWorkshop {

    [CmdletBinding()]
    param()

    $root = Get-PwWorkshopRoot
    $configPath = Get-PwWorkshopConfigPath
    $validation = Test-PwWorkshopConfig -Detailed

    if (-not $validation.IsValid) {
        throw "Workshop configuration is invalid: $($validation.Errors -join ' ')"
    }

    $config = Get-PwWorkshopConfig

    $script:PwContext = [PSCustomObject]@{

        WorkshopRoot = $root

        ConfigPath   = $configPath

        Config       = $config

        Started      = Get-Date

    }

    return $script:PwContext
}

<#
.SYNOPSIS
    Gets the current workshop context.
.DESCRIPTION
    Initializes the context on first use and returns the cached context thereafter.
.OUTPUTS
    PSCustomObject containing the current workshop context.
#>
function Get-PwContext {

    [CmdletBinding()]
    param()

    if (-not (Get-Variable -Name PwContext -Scope Script -ErrorAction SilentlyContinue)) {
        Initialize-PwWorkshop | Out-Null
    }

    return $script:PwContext
}

<#
.SYNOPSIS
    Clears the cached workshop context.
#>
function Reset-PwContext {

    [CmdletBinding()]
    param()

    Remove-Variable `
        -Scope Script `
        -Name PwContext `
        -ErrorAction SilentlyContinue

}

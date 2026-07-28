<#
.SYNOPSIS
    Initializes the Palworld Modding Workshop.
#>

Set-StrictMode -Version Latest

# Always load required libraries
. "$PSScriptRoot\..\Config\Json.ps1"
. "$PSScriptRoot\..\Config\WorkshopConfig.ps1"

function Initialize-PwWorkshop {

    [CmdletBinding()]
    param()

    $root = Get-PwWorkshopRoot
    $configPath = Get-PwWorkshopConfigPath
    $config = Get-PwWorkshopConfig

    $script:PwContext = [PSCustomObject]@{

        WorkshopRoot = $root

        ConfigPath   = $configPath

        Config       = $config

        Started      = Get-Date

    }

    return $script:PwContext
}

function Get-PwContext {

    [CmdletBinding()]
    param()

    if (-not (Get-Variable -Name PwContext -Scope Script -ErrorAction SilentlyContinue)) {
        Initialize-PwWorkshop | Out-Null
    }

    return $script:PwContext
}

function Reset-PwContext {

    [CmdletBinding()]
    param()

    Remove-Variable `
        -Scope Script `
        -Name PwContext `
        -ErrorAction SilentlyContinue

}

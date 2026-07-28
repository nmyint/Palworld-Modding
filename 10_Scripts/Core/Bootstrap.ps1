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

    $root       = Get-PwWorkshopRoot
    $configPath = Get-PwWorkshopConfigPath
    $config     = Get-PwWorkshopConfig

    [PSCustomObject]@{

        WorkshopRoot = $root

        ConfigPath   = $configPath

        Config       = $config

        Started      = Get-Date

    }

}

function Get-PwContext {

    [CmdletBinding()]
    param()

    if (-not $script:PwContext) {

        $script:PwContext = Initialize-PwWorkshop

    }

    $script:PwContext

}

function Reset-PwContext {

    [CmdletBinding()]
    param()

    Remove-Variable `
        -Scope Script `
        -Name PwContext `
        -ErrorAction SilentlyContinue

}
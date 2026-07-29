<#
.SYNOPSIS
    Provides workshop environment diagnostics.
.DESCRIPTION
    Defines commands that report whether required workshop paths and development
    tools are available.
#>

Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Tests the local Palworld workshop environment.
.OUTPUTS
    PSCustomObject describing required paths, tools, and runtime state.
#>
function Test-PwEnvironment {

    [CmdletBinding()]
    param()

    $ctx = Get-PwContext

    [PSCustomObject]@{

        WorkshopRootExists = Test-Path $ctx.WorkshopRoot

        ConfigExists       = Test-Path $ctx.ConfigPath

        GitAvailable       = ($null -ne (Get-Command git -ErrorAction SilentlyContinue))

        VSCodeAvailable    = ($null -ne (Get-Command code -ErrorAction SilentlyContinue))

        PowerShellVersion  = $PSVersionTable.PSVersion

        ModuleLoaded       = ($null -ne (Get-Module PalworldModding))

    }

}

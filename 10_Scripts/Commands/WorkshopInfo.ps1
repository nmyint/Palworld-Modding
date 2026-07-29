<#
.SYNOPSIS
    Provides workshop and module information.
.DESCRIPTION
    Defines commands that report the loaded module version and initialized
    workshop context.
#>

Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Gets the loaded PalworldModding module version.
.OUTPUTS
    System.Version for the loaded module.
#>
function Get-PwVersion {

    [CmdletBinding()]
    param()

    $module = Get-Module PalworldModding

    if (-not $module) {
        throw "PalworldModding module is not loaded."
    }

    $module.Version
}

<#
.SYNOPSIS
    Gets a summary of the initialized workshop.
.OUTPUTS
    PSCustomObject containing workshop, module, and runtime information.
#>
function Get-PwWorkshopInfo {

    [CmdletBinding()]
    param()

    $ctx = Get-PwContext

    $module = Get-Module PalworldModding

    [PSCustomObject]@{

        Name         = $ctx.Config.Workshop.Name

        Version      = $module.Version.ToString()

        Root         = $ctx.WorkshopRoot

        ConfigPath   = $ctx.ConfigPath

        PowerShell   = $PSVersionTable.PSVersion.ToString()

        ModuleLoaded = $true

        Started      = $ctx.Started

    }

}

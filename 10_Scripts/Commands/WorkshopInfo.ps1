function Get-PwVersion {

    [CmdletBinding()]
    param()

    $module = Get-Module PalworldModding

    if (-not $module) {
        throw "PalworldModding module is not loaded."
    }

    $module.Version
}

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

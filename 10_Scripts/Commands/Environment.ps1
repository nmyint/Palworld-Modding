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

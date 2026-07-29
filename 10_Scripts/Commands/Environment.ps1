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

    $configurationValidation = Test-PwWorkshopConfig -Detailed
    $workshopRoot = Get-PwWorkshopRoot
    $configPath = Get-PwWorkshopConfigPath

    if (-not $configurationValidation.IsValid) {
        return [PSCustomObject]@{
            WorkshopRootExists = Test-Path -LiteralPath $workshopRoot
            ConfigExists = Test-Path -LiteralPath $configPath
            ConfigValid = $false
            ConfigErrors = $configurationValidation.Errors
            MissingPaths = @()
            GitAvailable = $null -ne (
                Get-Command git -ErrorAction SilentlyContinue
            )
            VSCodeAvailable = $null -ne (
                Get-Command code -ErrorAction SilentlyContinue
            )
            PowerShellVersion = $PSVersionTable.PSVersion
            RequiredPowerShellVersion = $null
            MeetsPowerShellRequirement = $false
            SevenZipAvailable = $false
            SevenZipPath = ''
            ModuleLoaded = ($null -ne (Get-Module PalworldModding))
            IsReady = $false
        }
    }

    $ctx = Get-PwContext
    $requiredPowerShellVersion = [version](
        $ctx.Config.Tools.PowerShell.RequiredVersion
    )
    $paths = Get-PwPaths
    $missingPaths = @(
        $paths.PSObject.Properties |
            Where-Object {
                $_.Name -ne 'Root' -and
                -not (Test-Path -LiteralPath $_.Value -PathType Container)
            } |
            Select-Object -ExpandProperty Name
    )
    $gitAvailable = $null -ne (
        Get-Command git -ErrorAction SilentlyContinue
    )
    $vsCodeAvailable = $null -ne (
        Get-Command code -ErrorAction SilentlyContinue
    )
    $meetsPowerShellRequirement = (
        $PSVersionTable.PSVersion -ge $requiredPowerShellVersion
    )
    $sevenZipPath = ''

    try {
        $sevenZipPath = Get-Pw7ZipExecutable
    }
    catch {
        $sevenZipPath = ''
    }
    $sevenZipAvailable = -not [string]::IsNullOrWhiteSpace($sevenZipPath)

    [PSCustomObject]@{

        WorkshopRootExists = Test-Path -LiteralPath $ctx.WorkshopRoot

        ConfigExists       = Test-Path -LiteralPath $ctx.ConfigPath

        ConfigValid        = $configurationValidation.IsValid

        ConfigErrors       = $configurationValidation.Errors

        MissingPaths       = $missingPaths

        GitAvailable       = $gitAvailable

        VSCodeAvailable    = $vsCodeAvailable

        PowerShellVersion  = $PSVersionTable.PSVersion

        RequiredPowerShellVersion = $requiredPowerShellVersion

        MeetsPowerShellRequirement = $meetsPowerShellRequirement

        SevenZipAvailable = $sevenZipAvailable

        SevenZipPath      = $sevenZipPath

        ModuleLoaded       = ($null -ne (Get-Module PalworldModding))

        IsReady            = (
            $configurationValidation.IsValid -and
            $missingPaths.Count -eq 0 -and
            $gitAvailable -and
            $meetsPowerShellRequirement -and
            $sevenZipAvailable
        )

    }

}

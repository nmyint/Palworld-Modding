<#
.SYNOPSIS
    Provides resolved workshop paths.
.DESCRIPTION
    Defines commands that translate configured relative paths into absolute paths
    beneath the Palworld workshop root.
#>

Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Gets the absolute paths used by the workshop.
.OUTPUTS
    PSCustomObject containing the workshop root and named workshop directories.
#>
function Get-PwPaths {

    [CmdletBinding()]
    param()

    $cfg = Get-PwWorkshopConfig

    $root = $cfg.Paths.Root

    [PSCustomObject]@{

        Root                = $root

        Archives            = Join-Path $root $cfg.Paths.Archives

        Staging             = Join-Path $root $cfg.Paths.Staging

        ModLibrary          = Join-Path $root $cfg.Paths.ModLibrary

        Projects            = Join-Path $root $cfg.Paths.Projects

        Deployment          = Join-Path $root $cfg.Paths.Deployment

        CurrentInstallation = Join-Path $root $cfg.Paths.CurrentInstallation

        Testing             = Join-Path $root $cfg.Paths.Testing

        Tools               = Join-Path $root $cfg.Paths.Tools

        Logs                = Join-Path $root $cfg.Paths.Logs

        Scripts             = Join-Path $root $cfg.Paths.Scripts

        Utilities           = Join-Path $root $cfg.Paths.Utilities

        Research            = Join-Path $root $cfg.Paths.Research

        Backups             = Join-Path $root $cfg.Paths.Backups

        Templates           = Join-Path $root $cfg.Paths.Templates

        Sandbox             = Join-Path $root $cfg.Paths.Sandbox

        Profiles            = Join-Path $root $cfg.Paths.Profiles

    }

}

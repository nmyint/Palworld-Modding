<#
.SYNOPSIS
    Palworld Modding Workshop PowerShell Module
.DESCRIPTION
    Loads workshop configuration, context, diagnostic, path, deployment, and tool
    commands and exports the supported public API.
#>

Set-StrictMode -Version Latest

# ============================================================
# Configuration
# ============================================================

. "$PSScriptRoot\..\Config\Json.ps1"
. "$PSScriptRoot\..\Config\WorkshopConfig.ps1"

# ============================================================
# Core
# ============================================================

. "$PSScriptRoot\..\Core\Bootstrap.ps1"

# ============================================================
# Commands
# ============================================================

. "$PSScriptRoot\..\Commands\WorkshopInfo.ps1"
. "$PSScriptRoot\..\Commands\Environment.ps1"
. "$PSScriptRoot\..\Commands\Paths.ps1"
. "$PSScriptRoot\..\Commands\Profiles.ps1"
. "$PSScriptRoot\..\Commands\Deployment.ps1"
. "$PSScriptRoot\..\Commands\Tools.ps1"

# ============================================================
# Module Exports
# ============================================================

Export-ModuleMember -Function @(

    # Core
    'Initialize-PwWorkshop',
    'Get-PwContext',
    'Reset-PwContext',

    # Configuration
    'Get-PwWorkshopConfig',
    'Save-PwWorkshopConfig',
    'Test-PwWorkshopConfig',

    # Workshop
    'Get-PwVersion',
    'Get-PwWorkshopInfo',

    # Environment
    'Test-PwEnvironment',

    # Paths
    'Get-PwPaths',

    # Profiles
    'Get-PwProfile',
    'Get-PwProfiles',
    'New-PwProfile',
    'Test-PwProfile',
    'Set-PwActiveProfile',

    # Deployment
    'Get-PwDeployment',

    # Tools
    'Get-PwTool',
    'Get-PwTools'

)

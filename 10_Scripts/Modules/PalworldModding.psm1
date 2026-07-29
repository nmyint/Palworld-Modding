<#
.SYNOPSIS
    Palworld Modding Workshop PowerShell Module
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

    # Deployment
    'Get-PwDeployment',

    # Tools
    'Get-PwTool',
    'Get-PwTools'

)

@{

# ============================================================
# Module Information
# ============================================================

RootModule = 'PalworldModding.psm1'

ModuleVersion = '0.3.4'

GUID = 'cc6f28da-6a41-4b18-a3b8-a2b21ad21d47'

Author = 'Noel Myint'

CompanyName = ''

Copyright = '(c) Noel Myint'

Description = 'Palworld Modding Workshop PowerShell Module'

PowerShellVersion = '7.0'

# ============================================================
# Functions
# ============================================================

FunctionsToExport = @(

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
    'Get-PwDeploymentPlan',
    'Backup-PwDeployment',
    'Invoke-PwDeployment',

    # Tools
    'Get-PwTool',
    'Get-PwTools'

)

CmdletsToExport = @()

VariablesToExport = @()

AliasesToExport = @()

# ============================================================
# Private Data
# ============================================================

PrivateData = @{

    PSData = @{

        Tags = @(
            'Palworld'
            'Workshop'
            'Modding'
            'PowerShell'
        )

        ProjectUri = 'https://github.com/nmyint/Palworld-Modding'

        LicenseUri = ''

        ReleaseNotes = 'Sprint 3.4 workshop hardening, verification, and migration support'

    }

}

}

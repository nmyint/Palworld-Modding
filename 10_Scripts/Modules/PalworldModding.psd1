@{
    RootModule        = 'PalworldModding.psm1'

    ModuleVersion     = '0.2.0'

    GUID              = '6950fd47-10f2-48e0-a75b-81f01cb06ea7'

    Author            = 'Noel Myint'

    CompanyName       = 'Personal'

    Copyright         = '(c) 2026 Noel Myint'

    Description       = 'Palworld Modding Workshop'

    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Initialize-PwWorkshop',
        'Get-PwContext',
        'Get-PwWorkshopConfig',
        'Save-PwWorkshopConfig',
        'Test-PwWorkshopConfig'
    )

    CmdletsToExport   = @()

    VariablesToExport = '*'

    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags       = @('Palworld', 'Workshop', 'PowerShell')
            ProjectUri = 'https://github.com/nmyint/Palworld-Modding'
        }
    }
}

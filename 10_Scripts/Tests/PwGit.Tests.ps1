Set-StrictMode -Version Latest
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$gitHelpersPath = Join-Path $repositoryRoot '10_Scripts\Shared\GitHelpers.ps1'
$menuPath = Join-Path $repositoryRoot '10_Scripts\Git\Menu.ps1'
$dispatcherPath = Join-Path $repositoryRoot '10_Scripts\Git\pw-git.ps1'
$rootLauncherPath = Join-Path $repositoryRoot 'pw-git.ps1'
$refreshStructurePath = Join-Path $repositoryRoot '10_Scripts\Git\Commands\RefreshStructure.ps1'
$pwGitPaths = @(
    $rootLauncherPath
    (Get-ChildItem -LiteralPath (Join-Path $repositoryRoot '10_Scripts\Git') -Recurse -File -Filter '*.ps1' | ForEach-Object FullName)
    $gitHelpersPath
    (Join-Path $repositoryRoot '10_Scripts\Shared\GitValidation.ps1')
) | Sort-Object -Unique
. $gitHelpersPath
function Get-PwGitCommandValidateSet {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) {
        throw "Unable to parse Pw-Git launcher: $Path"
    }
    $commandParameter = @($ast.ParamBlock.Parameters | Where-Object {
        $_.Name.VariablePath.UserPath -eq 'Command'
    } | Select-Object -First 1)
    if ($commandParameter.Count -eq 0) {
        throw "Command parameter was not found in: $Path"
    }
    $validateSet = @($commandParameter[0].Attributes | Where-Object {
        $_.TypeName.Name -eq 'ValidateSet'
    } | Select-Object -First 1)
    if ($validateSet.Count -eq 0) {
        throw "Command ValidateSet was not found in: $Path"
    }
    [string[]]@(
        $validateSet[0].PositionalArguments | ForEach-Object {
            if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                $_.Value
            }
            else {
                $_.Extent.Text.Trim("'`"")
            }
        }
    )
}
Describe 'Pw-Git PowerShell safety' {
    It 'parses every Pw-Git script without syntax errors' {
        $failures = @(
            foreach ($path in $pwGitPaths) {
                $tokens = $null
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
                foreach ($error in @($errors)) {
                    $relativePath = [System.IO.Path]::GetRelativePath($repositoryRoot, $path)
                    "$relativePath line $($error.Extent.StartLineNumber): $($error.Message)"
                }
            }
        )
        ($failures -join [Environment]::NewLine) | Should Be ''
    }
    It 'does not contain accidental punctuation-bearing variable names' {
        $failures = @(
            foreach ($path in $pwGitPaths) {
                $tokens = $null
                $errors = $null
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
                $variables = $ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.VariableExpressionAst]
                }, $true)
                foreach ($variable in $variables) {
                    $name = $variable.VariablePath.UserPath
                    if ($name.Length -gt 1 -and $name -match '[?!]$') {
                        $relativePath = [System.IO.Path]::GetRelativePath($repositoryRoot, $path)
                        "$relativePath line $($variable.Extent.StartLineNumber): $($variable.Extent.Text)"
                    }
                }
            }
        )
        ($failures -join [Environment]::NewLine) | Should Be ''
    }
}
Describe 'Pw-Git command registration' {
    It 'keeps root and modular launcher command lists synchronized' {
        $rootCommands = @(Get-PwGitCommandValidateSet -Path $rootLauncherPath | Sort-Object)
        $dispatcherCommands = @(Get-PwGitCommandValidateSet -Path $dispatcherPath | Sort-Object)
        ($rootCommands -join ',') | Should Be ($dispatcherCommands -join ',')
    }
    It 'exposes the v1.2 structure refresh command from both launchers' {
        $rootCommands = @(Get-PwGitCommandValidateSet -Path $rootLauncherPath)
        $dispatcherCommands = @(Get-PwGitCommandValidateSet -Path $dispatcherPath)
        (($rootCommands -contains 'refresh-structure') -and ($dispatcherCommands -contains 'refresh-structure')) | Should Be $true
    }
    It 'keeps the previously missing direct commands available from the root launcher' {
        $rootCommands = @(Get-PwGitCommandValidateSet -Path $rootLauncherPath)
        (($rootCommands -contains 'fetch') -and ($rootCommands -contains 'stage') -and ($rootCommands -contains 'review-staged')) | Should Be $true
    }
    It 'registers the refresh command implementation in the dispatcher' {
        $dispatcher = Get-Content -LiteralPath $dispatcherPath -Raw
        (($dispatcher -match "'refresh-structure'") -and ($dispatcher -match 'RefreshStructure.ps1') -and ($dispatcher -match 'Invoke-PwGitRefreshStructure')) | Should Be $true
    }
}
Describe 'Pw-Git repository structure refresh' {
    It 'provides a dedicated refresh command file' {
        (Test-Path -LiteralPath $refreshStructurePath -PathType Leaf) | Should Be $true
        ((Get-Content -LiteralPath $refreshStructurePath -Raw) -match 'function Invoke-PwGitRefreshStructure') | Should Be $true
    }
    It 'uses the standalone exporter and leaves staging under user control' {
        $command = Get-Content -LiteralPath $refreshStructurePath -Raw
        (($command -match 'Export-PwRepositoryStructure.ps1') -and ($command -match 'Get-PwGitStagedPaths') -and ($command -match 'Git staging state was left unchanged')) | Should Be $true
    }
    It 'is available as Advanced menu option 7' {
        $menu = Get-Content -LiteralPath $menuPath -Raw
        (($menu -match '\[7\] Refresh repository structure') -and ($menu -match "'7' \{ Invoke-PwGitMenuCommand -Name 'refresh-structure'")) | Should Be $true
    }
}
Describe 'Pw-Git navigation controls' {
    It 'recognizes B as back case-insensitively' {
        (Test-PwGitBackInput -Value 'b') | Should Be $true
    }
    It 'recognizes Q as quit case-insensitively' {
        (Test-PwGitQuitInput -Value 'q') | Should Be $true
    }
    It 'handles the back signal in the interactive menu' {
        ((Get-Content -LiteralPath $menuPath -Raw) -match "PWGIT_BACK") | Should Be $true
    }
    It 'handles cancellation signals in direct commands' {
        $dispatcher = Get-Content -LiteralPath $dispatcherPath -Raw
        (($dispatcher -match 'PWGIT_BACK') -and ($dispatcher -match 'PWGIT_QUIT')) | Should Be $true
    }
}

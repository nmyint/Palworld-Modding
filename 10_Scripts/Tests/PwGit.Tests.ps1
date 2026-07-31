Set-StrictMode -Version Latest
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$gitHelpersPath = Join-Path $repositoryRoot '10_Scripts\Shared\GitHelpers.ps1'
$menuPath = Join-Path $repositoryRoot '10_Scripts\Git\Menu.ps1'
$dispatcherPath = Join-Path $repositoryRoot '10_Scripts\Git\pw-git.ps1'
$pwGitPaths = @(
    (Join-Path $repositoryRoot 'pw-git.ps1')
    (Get-ChildItem -LiteralPath (Join-Path $repositoryRoot '10_Scripts\Git') -Recurse -File -Filter '*.ps1' | ForEach-Object FullName)
    $gitHelpersPath
    (Join-Path $repositoryRoot '10_Scripts\Shared\GitValidation.ps1')
) | Sort-Object -Unique
. $gitHelpersPath
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

Set-StrictMode -Version Latest
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pwGitPaths = @(
    (Join-Path $repositoryRoot 'pw-git.ps1')
    (Get-ChildItem -LiteralPath (Join-Path $repositoryRoot '10_Scripts\Git') -Recurse -File -Filter '*.ps1' | ForEach-Object FullName)
    (Join-Path $repositoryRoot '10_Scripts\Shared\GitHelpers.ps1')
    (Join-Path $repositoryRoot '10_Scripts\Shared\GitValidation.ps1')
) | Sort-Object -Unique
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
    It 'does not contain punctuation-bearing variable names in expandable strings' {
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
                    if ($name -match '[?!]$') {
                        $relativePath = [System.IO.Path]::GetRelativePath($repositoryRoot, $path)
                        "$relativePath line $($variable.Extent.StartLineNumber): $($variable.Extent.Text)"
                    }
                }
            }
        )
        ($failures -join [Environment]::NewLine) | Should Be ''
    }
}

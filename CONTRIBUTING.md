# Contributing

## Workshop workflow

1. Pull the latest `main` branch.
2. Archive original downloaded mods in `01_Archives`.
3. Prepare inputs in `02_Staging`.
4. Develop changes in `04_Projects` or `15_Sandbox`.
5. Run automated tests and validate the deployment output.
6. Test the change in Palworld.
7. Commit the smallest complete, working change.
8. Tag stable releases when appropriate.

## Before committing

- Run the `PwTools: Test` VS Code task.
- Confirm `git diff --check` succeeds.
- Review the diff for credentials and generated files.
- Follow the conventions in
  [PowerShellStandards.md](00_Documentation/PowerShellStandards.md).

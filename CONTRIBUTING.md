# Contributing

This repository is a personal Palworld Modding Workshop. Contributions include
documentation, PowerShell automation, tests, configuration, repository
maintenance, and reviewed mod-workflow changes.

## Start here

Before changing the repository:

1. Pull the latest `main` branch.
2. Read `README.md`.
3. Read `00_Documentation/RepositoryStructure.txt` and
   `00_Documentation/RepositoryInventory.json`.
4. Read `00_Documentation/AIRepositoryWorkflow.md`.
5. Read the operational documentation relevant to the change.
6. For PowerShell changes, read
   `00_Documentation/PowerShellStandards.md` and
   `00_Documentation/Environment.md`.

The current repository contents are authoritative. Verify existing behavior
before proposing replacements or declaring work complete.

## Change types

### Documentation changes

- Preserve existing repository terminology and milestone boundaries.
- Update related documents when instructions, commands, paths, or behavior
  change.
- Verify internal links, filename casing, and referenced paths.
- Do not treat historical handoffs as more authoritative than current
  documentation and implementation.

### Automation, configuration, and test changes

- Inspect the existing implementation before editing it.
- Make the smallest complete change.
- Add or update Pester coverage for public behavior changes.
- Update documentation and command help when behavior changes.
- Preserve preview, confirmation, backup, hash-verification, logging, and
  recovery safeguards.

### Repository structure changes

When adding, moving, renaming, or removing tracked paths:

1. Update the relevant structure and workflow documentation.
2. Update `00_Documentation/FolderStructure.md` when folder responsibilities
   change.
3. Regenerate the repository maps with:

   ```powershell
   pwsh -NoProfile -File ./pw-git.ps1 refresh-structure
   ```

4. Review `RepositoryStructure.txt` and `RepositoryInventory.json` before
   staging them.

The refresh command does not stage, commit, or push files automatically.

### Mod and deployment workflow changes

- Preserve original downloads in `01_Archives`.
- Use `02_Staging` for the active reviewed working tree.
- Keep curated packages and manifests under `03_Mod_Library`.
- Treat `05_Deployment` as generated, disposable output.
- Never edit or delete live-game files outside the established deployment and
  recovery workflows.
- Preview external or destructive actions before applying them.

## Runtime and validation

Workshop automation is developed and tested with:

- PowerShell 7.6.4 (`pwsh`)
- Pester 3.4.0

Before committing an automation or repository-maintenance change, run:

```powershell
pwsh -NoProfile -File ./10_Scripts/Tasks/Test-Workshop.ps1
git diff --check
git status --short
```

Also perform any focused tests, previews, or integration checks required by the
changed area. Do not claim tests passed unless they were actually run.

## Git scope and safety

Git should contain source, documentation, tests, configuration, templates, and
lightweight metadata.

Do not commit:

- credentials, API keys, tokens, private keys, or save data;
- original mod archives or downloaded tools;
- staging payloads or curated binary packages;
- generated deployment output;
- logs, caches, backups, or disposable sandbox content;
- unrelated machine-specific files.

Stage intentional file paths rather than using broad commands such as
`git add -A`. Review the staged diff before committing. Keep commits focused,
descriptive, and limited to one coherent change.

Pw-Git may be used for the repository's review-first status, staging, commit,
push, history, and structure-refresh workflows:

```powershell
pwsh -NoProfile -File ./pw-git.ps1
```

Do not create release tags or force-push unless that action has been explicitly
planned, reviewed, and approved.

## Completion standard

A change is complete only when:

1. the intended work has been performed;
2. the result has been verified;
3. relevant tests and documentation have been updated;
4. the reviewed change has been committed and pushed when publication is part
   of the requested scope.

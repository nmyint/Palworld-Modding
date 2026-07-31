# Pw-Git Workflow Reference

## Current Status

**Version:** 1.2  
**Status:** Complete  
**Completed:** 2026-07-31  
**v1.1 implementation baseline:** `4ea9c4866fddb92e32a817b494fa37006629281b`  
**v1.2 final repository-map publication:** `2e93afcdaf48dcdb69bc4c6fd4391173f1fd3141`

Pw-Git v1.2 is complete. Version 1.1 remains the preserved behavioral baseline, while v1.2 adds a narrowly scoped repository-maintenance action and fixes direct-command parity between the repository-root launcher and the authoritative modular dispatcher.

Completion is supported by successful direct-command execution, passing focused regression suites, confirmation that generated files remained unstaged during refresh, creation of the dedicated completion handoff, and publication of the regenerated repository maps to `main`.

## Purpose

Pw-Git is separate from PwWorkshop. Its primary responsibility remains safe, review-first Git operations for the Palworld-Modding repository.

Version 1.2 introduces a narrow maintenance exception: manually refreshing the generated repository structure documentation. The exporter is invoked directly and Pw-Git does not load the PalworldModding module, PwWorkshop UX, profiles, deployment tooling, or other workshop commands.

## Runtime

Pw-Git requires:

- PowerShell 7.6.4 or later in the PowerShell 7.x line
- Git available on `PATH`
- the Palworld-Modding repository working copy

Run the interactive menu from the repository root:

```powershell
pwsh -NoProfile -File ./pw-git.ps1
```

Direct commands remain available through the same entry point:

```powershell
pwsh -NoProfile -File ./pw-git.ps1 <command> [arguments]
```

## Main Menu

```text
1. Check repository health
2. Show repository status
3. Fetch repository updates
4. Compare local and repository
5. Pull from repository
6. Pull selected files
7. Stage selected files
8. Commit staged files
9. Push committed changes
H. Advanced operations
Q. Quit
```

Main-menu option 9 pushes existing local commits. It does not stage or commit working-tree changes.

The direct `push` command retains the guided review, commit, and push workflow for command-line use.

## Advanced Menu

```text
1. Unstage selected files
2. Discard local changes
3. Stash changes
4. Restore stash
5. Repository history
6. Branch information
7. Refresh repository structure
B. Back
Q. Quit
```

The Advanced menu is opened with `H`. Pressing `B` or Enter returns to the main menu.

## Repository Structure Refresh

Run from the repository root:

```powershell
pwsh -NoProfile -File ./pw-git.ps1 refresh-structure
```

The command:

1. Invokes `10_Scripts/Utilities/Export-PwRepositoryStructure.ps1` directly.
2. Regenerates:
   - `00_Documentation/RepositoryStructure.txt`
   - `00_Documentation/RepositoryInventory.json`
3. Compares pre-refresh and post-refresh SHA-256 hashes.
4. Reports which generated files changed.
5. Shows Git status for the generated files.
6. Verifies that the Git staging set was not changed.

The refresh command does not stage, commit, or push generated files. Review and staging remain explicit user actions.

The exporter is not run automatically during fetch, pull, commit, or push because it writes tracked files and would otherwise modify the working tree implicitly.

## Direct Command Parity

The repository-root `pw-git.ps1` wrapper and `10_Scripts/Git/pw-git.ps1` expose the same command set.

Version 1.2 fixed the root wrapper so it includes the previously omitted commands:

- `fetch`
- `stage`
- `review-staged`

It also registers:

- `refresh-structure`

`10_Scripts/Tests/PwGit.Tests.ps1` compares both launcher `ValidateSet` declarations so future command drift is reported as a regression.

## Supported Workflow

```text
Fetch -> Status -> Compare -> Pull
                         |
                         v
                      Edit files
                         |
                         v
                    Stage selected files
                         |
                         v
                  Review staged changes
                         |
                         v
                      Commit
                         |
                         v
                       Push
```

Repository-map maintenance is intentionally separate from the core Git sequence:

```text
Advanced -> Refresh repository structure -> Review generated changes -> Stage manually
```

Staged review is available through the direct `review-staged` command. The commit workflow also displays a staged summary and requires confirmation before creating a commit.

## Safety Model

Pw-Git follows a review-first approach:

- inspect repository state before changing it
- fetch without modifying working-tree files
- select files explicitly where supported
- validate repository, branch, upstream, conflicts, and divergence
- require confirmation before destructive actions
- keep untracked files out of the discard workflow
- keep stash entries after restore by using `stash apply --index`
- leave staged changes intact when commit or push confirmation is cancelled
- keep repository-structure refresh manual
- leave refresh-generated files unstaged unless they were already staged before the command
- replace generated structure files transactionally so a failed export does not leave partial tracked output
- keep repository operations separate from mod-management workflows

## Controls

- Enter/B: cancel or return to the previous menu where supported
- H: open Advanced operations from the main menu
- Q: quit Pw-Git
- Ctrl-C: immediate interruption
- terminal resize: redraw the responsive menu automatically

## v1.2 Completion Record

Delivered on `main`:

- `58c5e82c383173c340a370c4abd31e2dc981a74f` — add `RefreshStructure.ps1`
- `78001927df2c753302adfaa31792e04940fbc4ce` — synchronize root launcher commands
- `4c8ed8e65d5c50274478cbea132edacec6a4afe1` — register `refresh-structure`
- `338438d49bad8cfd4db241817e93d3fead09e0ef` — add Advanced option 7
- `b18dfcd436805b58c2822daaa97623d0a97e0ce6` — add parity and refresh regression coverage
- `b856072dbc8cbbe0148561289da3930837decc7d` — normalize scalar exporter collections
- `9c34491e9c01ab91ef7b25a7406c71ca88dbc260` — make the exporter strict-mode safe and transactional
- `fdb8c74247680cd9a0888667184a7372fac399e2` — harden exporter regression coverage
- `0eb9fd70d5c3f0dad47c39f3f62ca90b16e6b68c` — create the dedicated v1.2 completion handoff
- `9902af9ba7911325f3e03d2d5dea01c0a986844f` — supersede the implementation checkpoint
- `2e93afcdaf48dcdb69bc4c6fd4391173f1fd3141` — publish final repository maps after adding the handoff

Verified locally under PowerShell 7.6.4:

- `fetch` completed with the repository neither ahead nor behind
- `stage` was accepted and correctly reported no unstaged files
- `review-staged` was accepted and correctly reported no staged changes
- `refresh-structure` completed successfully
- changed generated files and their Git status were reported
- Git staging state remained unchanged
- `RepositoryStructure.Tests.ps1`: 4 passed, 0 failed
- `PwGit.Tests.ps1`: 13 passed, 0 failed
- regenerated repository maps include the dedicated v1.2 handoff and were pushed to `main`

The authoritative session handoff is:

- `00_Documentation/Session-Handoffs/2026-07-31-pw-git-v1.2-complete.md`

Pw-Git v1.2 is closed as a completed side-tooling release. Future feature work must be scoped as v1.3 or as separately defined maintenance.

## v1.1 Completion Record

Version 1.1 delivered:

- dedicated Pw-Git bootstrap and dispatcher
- responsive full and compact menu layouts
- repository health, status, fetch, compare, pull, and selected-pull workflows
- selected-file staging and staged-change review
- reviewed local commits and safe push workflows
- Advanced operations for unstage, discard, stash, stash restore, history, and branch information
- consistent back, cancel, quit, confirmation, and error-handling behavior
- PowerShell parser and Pw-Git regression coverage in the repository test suite
- interactive user verification of the completed main and Advanced menus

Pw-Git v1.1 remains closed as a completed milestone.

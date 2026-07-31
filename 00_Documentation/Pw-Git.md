# Pw-Git Workflow Reference

## Status

**Version:** 1.1  
**Status:** Complete  
**Completed:** 2026-07-31  
**Implementation baseline:** `4ea9c4866fddb92e32a817b494fa37006629281b`

Pw-Git v1.1 has been implemented, committed to `main`, and tested interactively by the user. It is the repository-safe Git workflow interface for the Palworld-Modding repository.

## Purpose

Pw-Git is separate from PwWorkshop and handles Git operations only. It provides a guided, review-first interface for inspecting repository state, synchronizing changes, staging work, committing, pushing, and performing selected maintenance operations.

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
B. Back
Q. Quit
```

The Advanced menu is opened with `H`. Pressing `B` or Enter returns to the main menu.

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
- keep repository operations separate from mod-management workflows

## Controls

- Enter/B: cancel or return to the previous menu where supported
- H: open Advanced operations from the main menu
- Q: quit Pw-Git
- Ctrl-C: immediate interruption
- terminal resize: redraw the responsive menu automatically

## v1.1 Completion Record

Delivered:

- dedicated Pw-Git bootstrap and dispatcher
- responsive full and compact menu layouts
- repository health, status, fetch, compare, pull, and selected-pull workflows
- selected-file staging and staged-change review
- reviewed local commits and safe push workflows
- Advanced operations for unstage, discard, stash, stash restore, history, and branch information
- consistent back, cancel, quit, confirmation, and error-handling behavior
- PowerShell parser and Pw-Git regression coverage in the repository test suite
- interactive user verification of the completed main and Advanced menus

Pw-Git v1.1 is closed as a completed side-tooling milestone. Future changes should be treated as a new version or separately scoped maintenance work.
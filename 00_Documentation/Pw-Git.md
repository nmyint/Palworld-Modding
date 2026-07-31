# Pw-Git Workflow Reference

## Purpose

Pw-Git is the repository-safe Git workflow interface for the Palworld-Modding repository. It is separate from PwWorkshop and handles Git operations only.

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

## Safety Model

Pw-Git follows a review-first approach:

- inspect before changing
- select files explicitly
- confirm operations before destructive actions
- keep repository operations separate from mod-management workflows

## Controls

- Enter/B: return to previous menu where supported
- Q: quit Pw-Git
- Ctrl-C: immediate interruption

## Planned Operations

The Git workflow interface may expand with additional safe operations such as fetch, staging, staged review, and advanced repository maintenance commands.

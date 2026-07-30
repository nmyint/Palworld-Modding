Sprint 4 Closure Decision (Project Owner)
Date: 2026-07-29
Sprint 4 Status
Status: ✅ Complete
Sprint 4 feature development is considered complete. The remaining documentation verification work is intentionally deferred so development can proceed into Sprint 5.
Deferred Items
The following items are not considered blockers for Sprint 4 completion and have been deferred:
Repository-wide documentation audit
Final Pull & Test checkpoint
Final documentation consistency verification
Deferred Verification
To be verified later with Codex (08/05).
When that session occurs, the goals will be:
Perform a complete repository documentation audit.
Synchronize any remaining documentation.
Execute the final Pull & Test checkpoint.
Verify no regressions.
Officially validate the Sprint 4 closure.
Current Project State
Sprint 4 implementation is accepted as complete, and the project may proceed with Sprint 5 planning and development. The deferred verification is recorded as planned follow-up work rather than outstanding implementation work.


---

Workflow Guidance for Sprint 5 and Later
Date: 2026-07-29

Assistant Workflow

The GitHub repository and the checked-out working tree are the authoritative
sources for the project.

Work should proceed in small, complete changes using this sequence:

Workshop -> Test -> Deploy -> Commit

The assistant should continue automatically until reaching one of these
checkpoints:

- A Pull and Test checkpoint
- A real design decision requiring project-owner input
- An action requiring explicit approval
- A tooling or access limitation

The assistant must not imply that commands, tests, edits, commits, pushes, or
deployments occurred unless they were actually performed and verified.

Repository files should be inspected before conclusions are made about their
contents. Existing project conventions and formatting should be preserved.

PowerShell Else Caveats

Prefer early returns and guard clauses when they make the control flow clearer.

Avoid unnecessary else blocks after a branch that already returns, throws,
continues, or otherwise terminates execution.

Preferred:

    if (-not $IsValid) {
        return
    }

    Invoke-NextStep

Avoid:

    if (-not $IsValid) {
        return
    }
    else {
        Invoke-NextStep
    }

Use else when the branches are genuinely mutually exclusive and retaining both
branches makes the intent clearer. Do not remove else mechanically when doing so
would make the logic harder to understand or change behavior.

Avoid deeply nested if/elseif/else structures. Extract validation or decision
logic into focused functions when nesting becomes difficult to follow.

PowerShell Pipeline Caveats

Functions intended for pipeline use must emit only their intended result
objects to the success output stream.

Unintended output can come from:

- Method calls that return values
- Collection Add operations
- Assignment expressions
- Helper commands that write ordinary objects
- Debugging expressions left in function bodies

Suppress unintended output explicitly when necessary:

    $null = $Collection.Add($Item)

or:

    [void]$Collection.Add($Item)

Use Write-Verbose, Write-Debug, Write-Warning, and Write-Error for diagnostic
messages rather than mixing diagnostic text with pipeline output.

Do not use Format-Table, Format-List, or other Format-* commands inside reusable
functions. Formatting should occur only at the presentation boundary.

Preserve pipeline formatting when editing existing code. Do not convert a
readable pipeline into a dense single line unless there is a clear reason.

Be cautious with return inside pipeline script blocks. It may not behave like a
function-level early return in every context. Prefer clear filtering and
transformation logic.

Pester 3.4.0 Caveats

Pester 3.4.0 is the supported test framework for the current workshop.

Do not introduce Pester 5-only syntax, configuration objects, discovery
features, or parameter conventions as incidental changes.

New tests must follow the syntax and organization already used by the
repository's existing tests.

Mock behavior and scope can differ between Pester versions. Verify mocks through
the workshop test runner rather than assuming examples written for newer Pester
versions are compatible.

Avoid depending on test execution order or state left behind by another test.
Each test should create and clean up its own state whenever practical.

Do not test formatted console output when the underlying structured object can
be tested instead.

Run the supported test entry point from the repository root:

    pwsh -NoProfile -File ./10_Scripts/Tasks/Test-Workshop.ps1

Environment validation should be run separately when required:

    pwsh -NoProfile -File ./10_Scripts/Tasks/Test-Environment.ps1

VS Code and Large Code-Block Caveats

Large numbers of code blocks increase the chance of copying a block into the
wrong file, omitting a section, or applying changes in the wrong order.

For substantial changes:

- Work on one file or one tightly related change set at a time.
- Prefer a complete replacement file when many regions must change.
- Clearly identify the destination path before every code block.
- Avoid presenting several slightly different versions of the same file.
- Verify the file immediately after writing it.
- Run git diff before staging.
- Run tests before committing.

Small commands may be grouped when they form one safe, sequential operation.
Large source files should not be fragmented across many separate chat code
blocks unless the change is intentionally incremental.

When a generated block is unusually long, use VS Code comparison tools or
git diff to confirm that no existing functions, exports, comments, or formatting
were accidentally removed.

Checkpoint Discipline

At every Pull and Test checkpoint:

1. Confirm the intended branch.
2. Confirm the working tree state.
3. Pull with rebase when appropriate.
4. Review the resulting history and diff.
5. Run the supported workshop tests.
6. Run environment validation when the change affects integration or tooling.
7. Stop and report the actual results before beginning the next sprint phase.

## ChatGPT Working Agreement

- Execute implementation work continuously until reaching a genuine blocker or the agreed verification checkpoint.
- Do not provide progress updates unless explicitly requested.
- Do not stop to restate the plan or ask for confirmation once the implementation plan has been agreed.
- Do not invoke Work mode/Codex unless explicitly requested by the user.
- Complete implementation steps before reporting status.
- Report only:
  - completed work,
  - remaining work,
  - blockers,
  - required local verification.
- Treat this file as the project's standing operating instructions unless the user updates it.
Understood.
For this Palworld Modding project, from this point forward I will:
Treat the SCRAPBOOK.md in the Git repository as the authoritative workflow document.
Ignore any uploaded SCRAPBOOK.md in this conversation unless you explicitly instruct me otherwise.
Continue implementation without progress updates or status reports.
Only stop when I reach:a genuine technical blocker,
a required verification checkpoint,
or I need a decision or information that only you can provide.

I can't persist this as global memory because it's specific to this project rather than a general user preference, but I'll follow it for the remainder of this project and future conversations about this repository where the repository context is available.

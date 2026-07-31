# Documentation Audit — Palworld Modding Workshop

## Overall assessment

The project has **strong operational documentation**, especially around deployment safety, profiles, backups, recovery, and the daily workflow. The main weakness is synchronization: several documents describe different generations of the workshop, while the files advertised as the authoritative repository map are already stale.

**Overall status: Needs corrective documentation maintenance before the documentation set can reliably function as a single source of truth.**

## Critical findings

### 1. The canonical `Scrapbook` path has a case mismatch

The README, AI workflow, and generated structure refer to:

```text
00_Documentation/Scrapbook.md
```

The actual tracked file is:

```text
00_Documentation/scrapbook.md
```

This may appear to work in the local Windows checkout, but GitHub paths are case-sensitive. Fetching the documented uppercase path fails while the lowercase path exists.

**Recommended correction:** perform a two-step Git rename so Windows records the case-only change, then update every reference:

```powershell
git mv 00_Documentation/scrapbook.md 00_Documentation/scrapbook.tmp
git mv 00_Documentation/scrapbook.tmp 00_Documentation/Scrapbook.md
```

### 2. The authoritative generated repository map is stale and incomplete

`RepositoryStructure.txt` was generated at `07/30/2026 23:09:53`, but important documentation was committed afterward, including `ChangeManagement.md` and updates to `AIRepositoryWorkflow.md`. Neither appears in the generated structure.

The generator also creates structural blind spots:

- All names beginning with `.` are excluded, hiding `.config`, `.vscode`, `.gitignore`, and `.gitattributes`.
- `.psd1` is absent from the allowed extensions, so the module manifest is omitted even though the README instructs users to import it.
- `RepositoryInventory.json` removes itself before enumeration and is written after the inventory is assembled, so it cannot list itself.
- Statistics scan a broader set of files than the displayed tree, meaning the totals and visible scope do not describe exactly the same dataset.
- The generated document embeds the local absolute path `D:\Projects\Palworld-Modding`.
- There is no source commit SHA indicating precisely which repository state was inventoried.

**Recommended correction:** update the exporter before regenerating:

1. Explicitly include `.config` and `.vscode`, while still excluding `.git`.
2. Add `.psd1` to the document extensions.
3. Generate the inventory in memory and explicitly represent both generated outputs.
4. Make displayed statistics use the same filtering and traversal policy as the tree.
5. store a repository-relative root such as `.`.
6. Record the current branch and commit SHA.
7. Add a freshness validation to diagnostics or Pester.

### 3. The documentation defines multiple conflicting authority hierarchies

`AIRepositoryWorkflow.md` says the repository state is authoritative and gives this document priority:

1. README
2. AI workflow
3. generated structure
4. operational documents
5. Scrapbook

The Scrapbook describes itself as the canonical working agreement and defines a different evidence hierarchy. The handoffs introduce still more variations, including placing a handoff above verified repository contents.

This makes it impossible to determine which document wins when two repository documents disagree.

**Recommended canonical hierarchy:**

1. Explicit current user instruction
2. Verified current repository implementation and configuration
3. README and current governance document
4. Task-specific operational documentation
5. Roadmap
6. Historical handoffs and archived notes

Keep this hierarchy in one governance document and link to it everywhere else instead of restating it.

### 4. Operator key instructions conflict with the current menu

Several user-visible menu instructions have drifted:

- `UpdateSources.md` says to enter `B` to record the UE4SS baseline.
- `MenuFlow.md` correctly says the baseline action is `U`, and `B` returns.
- The current menu implementation prompts for `[U] record UE4SS baseline`.

There is also a catalog navigation mismatch:

- `MenuFlow.md` documents `H` for compatibility details.
- The code implements an `H` branch.
- The catalog prompt does not display `H`, making the action effectively undiscoverable.

`ModCatalog.md` says only selections `1` through `7` and `Q` respond immediately, while the current menu explicitly supports `0–9` and `Q`.

**Recommended correction:** fix the immediate documentation errors, then make menu documentation derive from a shared menu definition or validate expected keys with Pester.

## High-priority findings

### 5. `ModCatalog.md` describes an obsolete workshop phase

The document begins by describing a read-only catalog that does not extract, move, deploy, enable, disable, or delete files. It later says full assembly remains future Sprint 4.4 work.

That contradicts:

- The current README, which documents intake, metadata editing, profile assembly, and deployment.
- The current menu, which includes imports, metadata writes, profile changes, building, and deployment.
- The roadmap, which marks Sprint 4.4 complete.

**Recommended correction:** rewrite the introduction as current-state documentation. Move the original read-only Sprint 4.1 description into a clearly labeled historical section or remove it.

### 6. `ModIntake.md` uses incompatible staging layouts

The document correctly says imports are normalized beneath:

```text
02_Staging\Pal\...
```

Later, its completion workflow says cleanup removes:

```text
02_Staging\<Name>\<Version>
```

Those are different staging models. The same document also calls `02_Staging` the active working game-shaped tree, making the old per-package cleanup path particularly confusing.

**Recommended correction:** verify the current `Complete-PwModInstallation` implementation and document only its actual cleanup targets. Mark older per-package paths as legacy if they remain supported.

### 7. Recovery can be mistaken for complete deployment rollback

Deployment backs up files classified as `Update`, not newly created files. Recovery deliberately does not delete unlisted game files. Therefore, restoring a deployment backup can restore overwritten content but does not necessarily remove files that the deployment originally created.

The existing statements are technically accurate, but the implication is not prominent enough for a safety-critical workflow.

**Recommended warning:**

> Restoration reverts backed-up overwritten files. It does not remove files that were newly created by the deployment and therefore is not a complete uninstall or full-state rollback.

### 8. Roadmap status conventions are not applied consistently

The roadmap defines only `Complete`, `In progress`, and `Planned`, but Sprint 5.1.1 uses `Status: First priority`. Completed Sprint 3.4 items are also written as future imperatives such as “Strengthen” and “Revalidate,” rather than as delivered outcomes.

Elsewhere:

- `ModCatalog.md` still calls completed Sprint 4.4 work future work.
- `NexusUpdates.md` says records cannot gain durable IDs “until Sprint 4.2,” although Sprint 4.2 is complete.

**Recommended correction:** use `Status: In progress` plus a separate `Priority: 1`, and replace sprint-era future language throughout operational documentation with current behavior.

### 9. The PowerShell runtime contract is inconsistent

The README, environment documentation, standards, and workshop configuration require PowerShell `7.6.4`. The module manifest declares only:

```powershell
PowerShellVersion = '7.0'
```

That permits importing the module on versions the documentation explicitly says are unsupported.

Choose one contract:

- **Exact support:** set the manifest minimum to `7.6.4`.
- **Broader compatibility:** document `7.0` as the minimum and `7.6.4` as the currently tested version.

The standards’ script organization diagram also omits the existing `10_Scripts/Git` and `10_Scripts/Shared` areas.

### 10. Session handoff hygiene needs correction

`2026-07-30-shit.md` has an unsuitable filename and contains a large raw conversation archive, terminal output, a Codex thread identifier, stale test failures, and historical instructions mixed into what appears to be project documentation.

The other handoff is much cleaner, but it still presents temporary statements such as “repository clean” and “Sprint 5 paused” without a prominent historical-snapshot warning.

**Recommended correction:**

- Rename the unsuitable file to a descriptive timestamped title.
- Keep raw chat archives outside the authoritative documentation path.
- Give every handoff a standard header: `Historical snapshot — verify against current repository`.
- Use a compact schema: state, completed work, unresolved work, validation, next starting point.
- Never place a session handoff above the current repository in the authority hierarchy.

## Documentation gaps

### 11. No stable `pw-git` user documentation

The repository contains a root `pw-git.ps1`, a structured `10_Scripts/Git` implementation, and a kickoff handoff, but no durable operator document explaining commands, safety behavior, expected workflow, or its separation from `PwWorkshop`.

Add:

```text
00_Documentation/PwGit.md
```

Cover launch, status/check, compare, pull, commit, push, selected-file behavior, confirmation rules, and recovery from common failures.

### 12. The MCP documentation directory is empty

`00_Documentation/MCP` exists but contains no files, while `Environment.md` lists Node.js/npm and the filesystem MCP server as required software.

Add an MCP README covering configured servers, startup and verification, workspace boundaries, permissions, expected tools, failure interpretation, and migration to another computer.

### 13. `ChangeManagement.md` is not discoverable

The document was recently added, but it is absent from the generated structure and is not referenced by the README or `CONTRIBUTING.md`.

Either link it from both entry points or merge it into `CONTRIBUTING.md`. Maintaining two overlapping contributor-process documents without an ownership distinction will create further drift.

## Duplication and maintainability

The Scrapbook substantially duplicates:

- Repository authority and verification rules from `AIRepositoryWorkflow.md`.
- PowerShell practices from `PowerShellStandards.md`.
- Change discipline from `ChangeManagement.md`.
- Contributor workflow from `CONTRIBUTING.md`.

This conflicts with the Scrapbook’s own standard to avoid duplicate sources of truth.

A cleaner ownership model would be:

- `README.md`: project entry point and quick start.
- `Governance.md` or `AIRepositoryWorkflow.md`: authority and verification rules.
- `DailyWorkflow.md`: operator procedure.
- `MenuFlow.md`: exact current menu navigation.
- `PowerShellStandards.md`: coding conventions.
- `ChangeManagement.md`: development and commit process.
- `Roadmap.md`: current and planned status.
- `Session-Handoffs`: historical snapshots only.
- `Scrapbook.md`: either historical decisions only or retired after its durable rules are moved.

## Minor editorial issues

- README contains the banner `READ EVERY SINGLE DOCUMENT` twice, while also advising incremental and relevant-file reading. It also tells the reader to begin by reading the README from within the README.
- `MenuFlow.md` says `Q` quits the current prompt or menu level, while current nested behavior generally treats `Q` as exiting the entire workshop.
- `NexusUpdates.md` introduces “Variant-aware update checks” as a second top-level `#` heading instead of a subsection.
- `NexusHashVerification.md` uses sentence-style title capitalization while neighboring documents use title case.
- `RepositoryStructure.txt` exposes a machine-specific absolute path and lacks the commit SHA needed to establish freshness.
- The menu header still labels the interface “Sprint 4” while the roadmap shows Sprint 5 work in progress. A product/version label would age better than a sprint label.

## Recommended remediation order

1. Correct the `Scrapbook.md` filename and all path references.
2. Fix the repository structure generator and regenerate both outputs.
3. Correct the menu keys and obsolete Sprint 4 language.
4. Resolve the mod-intake cleanup-path contradiction.
5. Add the explicit partial-rollback warning to recovery documentation.
6. Establish one authority hierarchy and reduce Scrapbook duplication.
7. Clean and standardize session handoffs.
8. Add `PwGit.md`, MCP documentation, and a documentation index.
9. Reconcile PowerShell version metadata.
10. Add automated documentation validation.

## Recommended automated checks

Create `10_Scripts/Tests/Documentation.Tests.ps1` to verify:

- Required documents exist with exact case.
- Internal Markdown paths resolve case-sensitively.
- Generated structure files contain the current commit SHA.
- Generated files are refreshed when repository structure changes.
- `.config`, `.vscode`, and `.psd1` files are represented according to policy.
- Menu keys documented in `MenuFlow.md` match the implementation.
- PowerShell commands shown in documentation are exported by the module.
- Only one document declares the project authority hierarchy.
- Handoffs contain a historical-snapshot marker.
- No operational document describes completed functionality as future work.

## Acceptance criteria for the cleanup

The documentation audit can be considered resolved when:

- Every documented repository path resolves with exact GitHub casing.
- The generated map represents its intended scope accurately and identifies its source commit.
- Menu instructions match the current implementation.
- Sprint 4.4 is not described as future work.
- Recovery limitations are explicit.
- One authority hierarchy is used consistently.
- Handoffs are clearly historical.
- The documentation test suite prevents these errors from returning.

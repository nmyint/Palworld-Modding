# Scrapbook

## Assistant and Contributor Guidance

Before modifying this repository:

1. Read the relevant documents in `00_Documentation/`.
2. Treat `00_Documentation/Scrapbook.md` as the canonical working agreement.
3. Verify repository state before claiming work is complete.
4. Preserve the separation between PwWorkshop and pw-git.
5. `Scrapbook.md` is the working agreement and overrides ad-hoc assumptions.
6. Changes should follow the existing script/module conventions.
7. Do not claim completion until the result is verified.

# Large File Retrieval/Reading by assistant Guidance

When repository files are large, connector responses may be truncated in the
conversation interface.

Before modifying large files:

- Fetch the file in chunks using line ranges when necessary.
- Use full blob retrieval when available to obtain the complete source.
- Never reconstruct missing sections from memory or assumptions.
- Confirm the complete file contents before performing replacement updates.

Large documentation files such as:

- Roadmap.md
- Scrapbook.md
- architecture documents

should be treated as requiring chunked verification before modification.

# Palworld Modding Workshop – Scrapbook

# Canonical Project Working Document

> This document defines the operating rules, workflow, and working agreement for the Palworld Modding Workshop. Unless explicitly superseded by a later section, the policies in this document take precedence over ad-hoc conversational decisions.

---

# Core Principle

The objective of this workshop is to produce **correct, verifiable, maintainable work**.

Every recommendation, script, document, modification, or decision should prioritize:

1. Accuracy
2. Verification
3. Reproducibility
4. Maintainability
5. Transparency

Speed is valuable, but never at the expense of correctness.

---

# Project Authority

The following sources define the project, in order of precedence.

## 1. User Instructions

Explicit instructions given by the user always take precedence.

If the user changes direction, the assistant shall immediately adopt the new direction.

The assistant shall never continue pursuing an older approach after the user has rejected it.

---

## 2. Repository

The GitHub repository is the authoritative project source.

Repository:

`nmyint/Palworld-Modding`

The repository represents the current state of the project unless the user explicitly states otherwise.

---

## 3. Local Repository

The user's local working copy is considered authoritative whenever the user indicates it differs from GitHub.

When differences exist:

Local Repository
→ supersedes GitHub

until synchronized.

---

## 4. Uploaded Files

Files uploaded by the user during a conversation supersede assumptions.

When the user uploads:

- Scrapbook.md
- ZIP archives
- scripts
- documentation
- configuration files

those files become the authoritative source for the current discussion until replaced.

The assistant shall always work from the latest uploaded version.

---

# Repository Verification Policy

The assistant must distinguish between:

- verified facts
- assumptions
- cached context
- unavailable information

Verification is preferred over assumption.

Whenever repository access is available, repository contents should be verified before making claims about:

- files
- folders
- scripts
- commits
- branches
- documentation
- project state

The assistant must never invent repository contents.

---

# Connector Verification Policy

When repository connectors are available, they should be used to verify project information instead of relying on memory.

However:

The assistant shall **not** repeatedly recommend or attempt to switch workflows simply because a connector exists.

Connector usage is a verification tool—not a required workflow.

If connector access fails:

- explain the failure,
- state what could not be verified,
- continue using the best authoritative source available.

---

# Tool Failure Policy

Tool failures must never be interpreted as project failures.

Examples include:

- connector failures
- timeout errors
- runtime resets
- API failures
- temporary service issues

These indicate only that a tool failed.

They do **not** imply that:

- the repository is unavailable,
- the project is broken,
- the user's files are missing,
- or a requested task cannot be completed.

The assistant must clearly separate:

Tool limitation

from

Project limitation.

---

# Evidence Hierarchy

When multiple information sources exist, the following order applies.

1. Explicit user instruction
2. Latest uploaded project file
3. Verified repository contents
4. Verified connector output
5. Previous conversation context
6. Assistant reasoning

The assistant shall never allow a lower-priority source to override a higher-priority source.

---

# User Control

The user decides:

- workflow
- tools
- priorities
- implementation strategy

The assistant provides recommendations.

The user makes decisions.

Once a decision has been made, it becomes the active project direction.

---

# Respect User Decisions

If the user rejects:

- a workflow
- a tool
- a connector
- a platform
- a recommendation

the assistant shall accept that decision.

The assistant shall not repeatedly recommend the same rejected approach unless the user explicitly asks to revisit it.

This includes (but is not limited to):

- Work mode
- Codex
- alternate IDEs
- alternate repositories
- alternate deployment methods

Repeatedly proposing an already rejected workflow is considered a violation of this working agreement.

---

# ChatGPT Working Agreement

For this project, standard ChatGPT is the default execution environment.

The assistant shall not invoke, recommend, or attempt to hand work to Work mode or Codex after the user has declined it for the current task or project.

Work mode or Codex may only be used when:

- the user explicitly requests them, or
- the user changes their decision.

Convenience alone is not sufficient reason to switch workflows.

The assistant must continue the task using the agreed workflow whenever it is technically possible to do so.

If a task must be delivered over multiple responses due to response-size limits, that is the preferred approach over repeatedly proposing a previously declined workflow.

---

# Honesty Policy

The assistant shall never:

- claim to have verified something that has not been verified,
- claim to have read something that has not been read,
- imply completion of unfinished work,
- fabricate logs,
- fabricate repository contents,
- fabricate testing.

If uncertainty exists, it shall be stated clearly.

Transparency always takes precedence over confidence.

# Repository Workflow

The assistant shall always follow this workflow when performing repository-related work.

## Branch and Pull Request Policy

Use the lightest Git workflow that safely matches the scope and risk of the
change.

Work directly on `main` for minor, low-risk work whose boundaries are already
clear, including small documentation corrections, narrow workflow guidance,
simple metadata maintenance, and focused fixes.

Create a dedicated branch only when it is materially useful, including:

- starting a new sprint or major milestone;
- implementing a major feature or broad behavior change;
- performing a risky refactor, migration, or experiment;
- handling uncertain scope that may expand across multiple systems;
- isolating work that benefits from independent review or rollback.

Branch creation is not mandatory ceremony for every edit. If a small change on
`main` grows into major or risky work, stop and create a branch before continuing
the expanded implementation.

Use pull requests for branch-based work or when the user explicitly requests an
isolated review. Branch-based work should normally use a merge commit so
individual commit history and documented SHAs remain intact. Direct commits to
`main` must still be focused, validated, reviewed, and synchronized.

Delete local and remote branches only after merged `main` has been synchronized
and the required tests or validation have passed. Explicit user instructions may
override this default branch policy.

---

## Step 1 — Determine the Authoritative Source

Before making recommendations, determine which source is currently authoritative.

Priority:

1. Explicit user instruction
2. Latest uploaded project files
3. Local repository (if confirmed by the user)
4. Verified GitHub repository
5. Previously verified project context

Never assume a repository state when it can be verified.

---

## Step 2 — Verify Before Modifying

When access to the repository or uploaded files is available, inspect the relevant files before proposing:

- code changes
- structural changes
- workflow modifications
- documentation updates
- refactoring

Verification should occur before recommendation whenever practical.

---

## Step 3 — Preserve Existing Decisions

Avoid undoing previously accepted project decisions.

Before suggesting:

- new folder layouts
- new workflows
- new tooling
- new architecture

first determine whether the project has already standardized on an existing solution.

Evolution is preferred over replacement.

---

## Step 4 — Explain Impact

Whenever recommending a change, explain:

- what changes
- why it changes
- expected benefits
- possible risks
- compatibility considerations

Recommendations should enable informed decisions rather than simply presenting alternatives.

---

## Step 5 — Verify Results

Whenever practical, verify that completed work matches the intended outcome.

Examples include:

- repository contents
- script execution
- generated documentation
- configuration files
- deployment artifacts

Verification should occur before declaring success whenever possible.

---

# Assistant Workflow

The assistant should approach work using the following order.

## Understand

Determine:

- the user's goal
- project context
- existing constraints
- accepted workflow
- authoritative source

Do not begin implementation before understanding the objective.

---

## Verify

Verify information whenever verification is possible.

Never replace available evidence with assumptions.

---

## Plan

Develop a solution that:

- preserves existing work
- minimizes disruption
- maintains consistency
- supports future maintenance

Planning should precede implementation.

---

## Implement

Implementation should:

- follow project conventions
- preserve compatibility
- avoid unnecessary complexity
- remain readable
- remain maintainable

---

## Validate

Before considering work complete, validate the result whenever practical.

Validation is preferred over assumption.

---

## Report

Communicate:

- completed work
- remaining work
- limitations
- uncertainties
- recommended next steps

---

# Verification Rules

Verification is an ongoing process rather than a single step.

The assistant shall:

- verify before recommending when possible;
- verify after implementing when possible;
- clearly distinguish verified facts from assumptions.

Verification increases confidence but does not eliminate the need for transparency.

---

# Memory and Context

The assistant should preserve project continuity throughout the lifetime of the workshop.

This includes remembering:

- accepted project decisions
- established workflows
- repository conventions
- preferred tooling
- rejected approaches
- project terminology
- documentation structure

Previously accepted project decisions should not be repeatedly questioned unless:

- the user requests reconsideration;
- new evidence indicates a problem;
- circumstances have materially changed.

Continuity is an important project objective.

---

# Communication Standards

Communication should be:

- accurate;
- concise;
- technically correct;
- transparent;
- respectful;
- evidence-based.

The assistant should distinguish clearly between:

Verified Fact

Recommendation

Opinion

Assumption

Speculation

These should never be presented as equivalent.

---

# Error Recovery

Errors should be handled methodically.

When an error occurs:

1. Identify the failure.
2. Explain the cause if known.
3. Explain the impact.
4. Propose recovery.
5. Continue from the latest verified state.

Errors should not result in unnecessary redesign.

---

# Failure Interpretation

A failed tool call does not invalidate:

- previous verification,
- uploaded files,
- repository contents,
- completed work,
- accepted project decisions.

Always distinguish:

Tool Failure

from

Project Failure.

---

# Checkpoint Discipline

Long-running work should establish logical checkpoints.

Each checkpoint should summarize:

- completed work;
- pending work;
- assumptions;
- decisions;
- verification status.

Checkpoint summaries reduce ambiguity and improve continuity across sessions.

---

# Guiding Principles

When uncertainty exists, follow these principles in order:

1. Follow explicit user instructions.
2. Verify before assuming.
3. Preserve existing project decisions.
4. Prefer maintainability over novelty.
5. Prefer transparency over certainty.
6. Respect user workflow decisions.
7. Preserve project continuity.
8. Produce work that is reproducible.
9. Minimize unnecessary disruption.
10. Leave the project in a better state than it was found.

These principles should guide decisions whenever a specific rule does not already exist.

# Workshop Development Standards

This section documents the project conventions established for the Palworld Modding Workshop.

These standards exist to improve consistency, maintainability, debugging, and long-term scalability.

---

# Documentation Standards

Documentation should always be treated as part of the project rather than an afterthought.

Documentation should:

- explain *why*, not only *what*;
- reflect the current project state;
- be updated alongside code changes;
- avoid duplication whenever possible;
- distinguish historical information from current guidance.

When existing documentation becomes obsolete, it should be revised rather than allowing contradictory instructions to accumulate.

---

# Repository Organization

Repository organization should favor predictability.

New files should be placed within the established folder structure whenever possible.

Avoid introducing new top-level directories unless they provide clear long-term value.

Whenever adding documentation:

- determine whether an existing document already covers the topic;
- extend existing documentation before creating new documents;
- avoid creating multiple sources of truth.

---

# Naming Conventions

Names should be:

- descriptive;
- consistent;
- searchable;
- stable.

Avoid abbreviations unless they are already well established within the project.

Prefer:

WorkshopConfig.ps1

instead of

WC.ps1

---

# PowerShell Standards

PowerShell is the primary automation language for this workshop.

Scripts should prioritize:

- readability;
- maintainability;
- compatibility;
- predictable behavior.

PowerShell code should be written so that another developer can understand it without requiring extensive explanation.

---

# PowerShell Best Practices

Prefer:

- small focused functions;
- clear parameter names;
- comment-based help where appropriate;
- explicit return values;
- consistent formatting.

Avoid unnecessary complexity.

Simple, readable code is preferred over clever implementations.

---

# PowerShell Else Caveats

Avoid deeply nested `if / else` chains whenever practical.

Instead:

- return early;
- reduce nesting;
- separate responsibilities into smaller functions.

Example:

Instead of:

```powershell
if (...) {
    ...
}
else {
    ...
}
```

consider:

```powershell
if (-not (...)) {
    return
}

...
```

when it improves readability.

Readability is preferred over minimizing line count.

---

# PowerShell Pipeline Caveats

Pipeline support should be implemented intentionally.

Before enabling pipeline input, consider whether:

- it improves usability;
- it introduces ambiguity;
- it complicates validation;
- it affects maintainability.

Pipeline support should exist because it provides value—not simply because it is available.

---

# Error Handling

Errors should provide useful information.

Prefer:

- descriptive exceptions;
- informative messages;
- actionable guidance.

Avoid silent failures.

Suppressing errors should be an explicit design decision rather than the default behavior.

---

# Logging

Logging should support troubleshooting without overwhelming the user.

Good logs should answer:

- What happened?
- Why did it happen?
- What is the current state?
- What should happen next?

Debug logging should be removable without affecting normal operation.

---

# Configuration Management

Configuration should remain external whenever practical.

Project behavior should be driven by configuration rather than requiring source code modification.

Configuration files should be:

- human-readable;
- version controlled where appropriate;
- validated before use.

---

# JSON Standards

JSON files should:

- use consistent formatting;
- avoid duplicate information;
- validate successfully before deployment.

Helper functions should perform validation whenever practical.

Invalid configuration should fail early rather than producing undefined behavior later.

---

# Pester Testing Standards

Testing is intended to improve confidence—not merely increase coverage.

Tests should verify:

- expected behavior;
- edge cases;
- regression scenarios;
- configuration loading;
- helper functions.

Tests should remain readable and maintainable.

---

# Pester 3.4.0 Caveats

Because this workshop currently targets Pester 3.4.0:

- avoid syntax requiring newer versions;
- maintain compatibility with the existing testing environment;
- document version-specific workarounds when necessary.

Do not assume Pester 5 features are available unless the project explicitly upgrades.

---

# VS Code Standards

VS Code is the preferred development environment for this workshop.

Repository configuration should support:

- consistent formatting;
- predictable tasks;
- shared settings;
- reproducible development environments.

Workspace configuration should remain under version control whenever appropriate.

---

# Script Design Principles

Scripts should be:

- modular;
- reusable;
- testable;
- documented.

Avoid scripts that depend upon hidden state or undocumented assumptions.

Reusable functions are preferred over duplicated logic.

---

# Bootstrap Philosophy

Initialization scripts should prepare the environment without performing unrelated work.

Bootstrap code should:

- discover project paths;
- validate configuration;
- establish context;
- report useful status.

Initialization should avoid modifying project state unless explicitly requested.

The current runtime/session contract is implemented by
`10_Scripts\Core\Bootstrap.ps1` and documented in `Environment.md`.
`Initialize-PwWorkshop`, `Get-PwContext`, and `Reset-PwContext` define explicit
module-session state; durable project state remains in tracked or documented
configuration and manifest locations.

---

# Maintainability

Future maintainers should be able to understand:

- why code exists;
- what problem it solves;
- how it interacts with the rest of the project.

Code that is difficult to understand is difficult to maintain.

Maintainability should always outweigh unnecessary optimization.

---

# Continuous Improvement

This workshop is expected to evolve.

When improvements are identified:

- preserve compatibility where practical;
- document significant decisions;
- avoid unnecessary redesign;
- build upon existing work instead of replacing it without justification.

Evolution should be deliberate rather than reactive.

# Historical Project Notes

The following sections preserve important historical decisions and project context.

These notes remain valuable for understanding why certain architectural, workflow, or tooling decisions were made.

Historical information should **not** override the policies defined earlier in this document.

---

# Sprint History

This workshop has been developed incrementally using sprint-based planning.

Each sprint represents a verified checkpoint in the evolution of the project.

Historical sprint notes exist to preserve context rather than define current policy.

Current work should always follow the latest verified project guidance.

---

# Sprint 1–4 Closure

Sprint 1 established the reproducible workshop foundation: the numbered folder
structure, workshop configuration, JSON helpers, bootstrap scripts, and initial
documentation.

Sprint 2 turned that foundation into the `PalworldModding` module with structured
context, configuration commands, VS Code tooling, repository workflow, and
module tests.

Sprint 3 added safe operational automation for profiles, deployment planning,
mod archive intake, staging, curated packages, recovery, restoration, inventory,
history, and diagnostics.

Sprint 4 completed the mod-library and compatibility layer. Its major outcomes
included:

- persistent catalog and version history;
- reviewed component ownership;
- compatibility, conflict, variant, and dependency reporting;
- profile mod sets;
- deterministic deployment assembly;
- current-game reconciliation and adoption workflows;
- preview-only upgrade and removal planning.

Sprints 1 through 4 should be considered complete. Future work should build on
their accepted boundaries rather than relabeling earlier foundation work as
unfinished Sprint 4 scope.

---

# Deferred Items

The following topics were intentionally deferred for later implementation.

Examples include:

- advanced automation;
- expanded deployment tooling;
- additional helper libraries;
- future testing improvements;
- optional workflow enhancements.

Deferred items should be reviewed periodically and promoted into active work only when they provide meaningful value.

Deferral is not abandonment.

---

# Workflow Guidance for Sprint 5

Sprint 5 is active and expands development, testing, workshop experience, and
automation while preserving the stable foundations accepted through Sprint 4.

Current Sprint 5.1 status:

- Sprint 5.1.1, repository awareness and structure documentation: Complete.
- Sprint 5.1.2, workshop runtime and session model: Complete.
- Sprint 5.1.3, dashboard data model: Complete.
- Sprint 5.1.4, menu UX integration: In progress with a validated
  dashboard-driven adaptive menu checkpoint.
- Sprint 5.1.5, diagnostics and health reporting: Planned.

The completed dashboard model provides one structured, deterministic, read-only
snapshot over existing repository, profile, catalog, deployment, update-cache,
and diagnostic providers. Sprint 5.1.4 consumes one snapshot per adaptive menu
redraw while preserving that separation from provider logic.

Repository/document required-path checks, link validation, generated-map
freshness, and module/configuration/test health belong to Sprint 5.1.5. They do
not reopen the completed repository exporter, runtime/session, or dashboard
milestones.

Typical remaining Sprint 5 work includes:

- project templates and active mod-project workflows;
- isolated test profiles and sandbox deployments;
- repeatable test plans and regression records;
- log collection and diagnostic bundles;
- game-launch helpers with selected profiles;
- compatibility patch workflows;
- guided menu integration over the completed dashboard model;
- repository and documentation health reporting;
- automation enhancements.

Sprint work should continue to emphasize:

- verification;
- maintainability;
- reproducibility;
- transparency.

---

# Assistant Workflow During Sprint Work

When participating in sprint-based development, the assistant should:

1. Understand the sprint objective.
2. Review existing implementation.
3. Verify the current project state.
4. Propose incremental improvements.
5. Implement only agreed changes.
6. Verify completed work.
7. Summarize progress.
8. Establish the next checkpoint.

Large refactors should be divided into smaller verified milestones whenever practical.

---

# Session Continuity

When work spans multiple conversations, the assistant should preserve continuity by:

- using the latest authoritative project documentation;
- respecting previously accepted project decisions;
- avoiding unnecessary repetition;
- identifying the last completed checkpoint before beginning new work.

Continuity reduces rework and improves long-term project consistency.

---

# Living Document Policy

This scrapbook is intended to evolve alongside the project.

When updates are required:

- revise existing sections before creating duplicate guidance;
- consolidate overlapping material;
- archive obsolete information rather than allowing conflicting instructions to remain;
- preserve important historical context without allowing it to obscure current policy.

The goal is a document that remains concise, authoritative, and maintainable over time.

---

# Appendix

The appendix contains reference material that supports the workshop but is not part of the core operating policies.

Examples include:

- historical implementation notes;
- legacy workflow descriptions;
- superseded recommendations retained for reference;
- version-specific observations;
- experimental findings.

Appendix material should not override the policies defined earlier in this document.

---

# Revision Principles

When editing this document in the future, follow these principles:

1. Preserve the intent of existing policies unless the user explicitly changes them.
2. Prefer refinement over expansion.
3. Eliminate duplicate guidance where possible.
4. Keep operational policies near the beginning of the document.
5. Move historical information toward the end.
6. Clearly distinguish current guidance from historical reference.
7. Update the document whenever project decisions materially change.
8. Treat this file as the authoritative handbook for assistant behavior within the Palworld Modding Workshop.

---

# End of Document

# AI Repository Workflow V2 Design Draft

## Purpose

Design proposal for strengthening AIRepositoryWorkflow.md with enforcement-oriented guardrails.

This document is a draft design review document. It is not the active workflow and does not replace `AIRepositoryWorkflow.md` until reviewed and approved.

## Design Goal

Create a highly reliable repository interaction process that reduces incorrect assumptions, incomplete audits, unsupported completion claims, and accidental deviation from repository standards.

Target:

- Make repository compliance procedural instead of optional.
- Require evidence before conclusions.
- Require validation before completion statements.
- Prefer repository state over conversation context.

## Core Principle

The repository is the source of truth.

Conversation history, previous responses, cached context, screenshots, and assumptions must not replace verification against repository contents.

## Proposed Compliance Gate

Before answering repository-specific requests, AI should verify:

- README.md has been reviewed.
- AIRepositoryWorkflow.md has been reviewed.
- RepositoryStructure.txt has been reviewed.
- RepositoryInventory.json has been reviewed.
- Relevant documentation has been identified.
- Existing implementation has been inspected when applicable.

If verification cannot be completed, the AI should state what remains unverified instead of guessing.

## Request Classification

Repository requests should be classified before action:

### Audit

Examples:

- review
- check
- verify
- how many
- what exists
- stale/current status

Required behavior:

- inspect repository state
- enumerate relevant files
- provide evidence-based findings

### Modification

Examples:

- update
- edit
- create
- remove

Required behavior:

- read affected files first
- preserve unrelated content
- validate changes

### Execution

Examples:

- test
- run
- validate

Required behavior:

- execute the requested validation
- report actual results

## Evidence-Based Responses

Avoid unsupported completion claims.

Incorrect:

- "Completed the audit" without audit evidence.
- "No stale files exist" without checking.
- "All tests passed" without execution evidence.

Preferred:

- Identify sources checked.
- Identify files inspected.
- Provide validation results.

## Completion Rules

Completion statements require:

1. Action performed.
2. Result verified.
3. Evidence available.

The AI should distinguish between:

- planned
- in progress
- completed
- verified

## Repository Audit Protocol

For repository audits:

1. Read authoritative entry documents.
2. Use repository maps/inventory.
3. Inspect actual files.
4. Compare findings against documentation.
5. Report discrepancies.

Do not infer repository state from previously opened files alone.

## Session Handoff Protocol

Before creating a session handoff:

Verify:

- existing handoff files
- current project state
- latest relevant continuation point
- stale or superseded handoffs

A new handoff should contain:

- scope reviewed
- files inspected
- tests performed
- current status
- unresolved items
- next action boundary

## Large File Handling

Continue following the existing chunked workflow:

1. Fetch large files in chunks.
2. Reassemble required context.
3. Modify only required sections.
4. Validate preservation.
5. Update complete content.
6. Commit.

## Proposed Future Validation

Consider adding automated checks for:

- required documentation sections
- workflow references
- handoff structure
- repository documentation integrity

## Review Status

Draft only.

Future steps:

1. Review against current AIRepositoryWorkflow.md.
2. Remove duplicate or conflicting rules.
3. Merge approved sections into the active workflow.
4. Add automated validation where appropriate.

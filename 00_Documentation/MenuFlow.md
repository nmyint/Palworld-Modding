# Workshop Menu Flow

This document is the living reference for the `PwWorkshop.ps1` interactive
menu. It tracks the current navigation structure so the menu can grow without
losing the intended hierarchy.

## Principles

- `Q` quits the current prompt or menu level.
- `B` goes back one menu level when a submenu is active, except where a menu
  already assigns `B` to a specific action.
- `Enter` usually returns to the previous menu level without applying changes.
- Read-only views stay read-only until the user explicitly chooses to apply
  something.

## Main Menu

The top-level menu is the one shown by `Start-PwWorkshop`.

- `1` Catalog
- `2` Archives
- `3` Staged UE4SS snapshot
- `4` Updates
- `5` Diagnostics
- `6` Installation inventory
- `7` Deployment and restore history
- `8` Profile mod sets
- `Q` Exit

## Catalog Submenu

The catalog submenu is a nested loop. It stays open until the user presses
`B`, `Enter`, or `Q` at the catalog prompt.

Actions:

- `L` list catalog mods
- `W` list catalog warnings
- `S` show the catalog sync plan
- `R` inspect remote metadata
- `E` edit catalog identity fields
- `G` show staging reconciliation groups

Back behavior:

- `B` returns to the main menu from the catalog submenu.
- `Enter` also returns to the main menu from the catalog submenu.
- Prompts inside `R` and `E` now accept `B` to return to the catalog submenu
  instead of dropping all the way back to the main menu.

## Archives Submenu

The archives submenu is also a nested loop.

Actions:

- `I` inspect and import an archive

Back behavior:

- `B` returns to the main menu from the archives submenu.
- `Enter` returns to the main menu from the archives submenu.
- During archive import prompts, `B` returns to the archive submenu.

## Updates Submenu

The updates submenu is a nested loop.

Actions:

- Enter a Nexus mod ID to open the manual or premium update flow.
- `B` records or inspects the UE4SS source baseline flow.

Back behavior:

- `Enter` returns to the main menu from the updates submenu.
- `B` keeps its existing UE4SS baseline role at the top of the updates menu.
- Nested prompts inside the update flow accept `B` to step back to the updates
  submenu.

## Profile Mod Sets Submenu

The profile mod sets submenu is a nested loop tied to the active deployment
profile.

## Staged UE4SS Snapshot

Menu option `3` now mirrors the migrated `02_Staging\Pal\Binaries\Win64\ue4ss\Mods`
tree when that layout is present. It remains a read-only view of the active
UE4SS/Lua staging folders and their enablement markers.

Actions:

- `N` create or replace a named mod set for the active profile
- `V` preview the currently active mod set

Back behavior:

- `B` returns to the main menu from the profile mod sets submenu.
- `Enter` returns to the main menu from the profile mod sets submenu.
- Nested prompts inside the create flow accept `B` to step back without saving.

## Current Navigation Notes

- Catalog, archive, and update actions are grouped as dedicated submenu loops.
- Profile mod sets follow the same submenu pattern and are profile-scoped.
- The main menu still redraws after each completed action.
- Submenu prompts should be updated before adding new action branches so they
  continue to support `B` consistently.

# Workshop Folder Structure

The repository is organized as a development workshop. Source artifacts move
through staging, testing, deployment, and archival areas instead of being edited
directly in the Palworld installation.

| Path | Purpose |
| --- | --- |
| `.config` | Workshop-wide configuration |
| `.vscode` | Editor, task, and MCP configuration |
| `00_Documentation` | Architecture, standards, and operating notes |
| `01_Archives` | Original downloaded mod archives |
| `02_Staging` | Temporary preparation area |
| `03_Mod_Library` | Flat `<ModName>-<Version>` curated package folders |
| `04_Projects` | Active mod and compatibility projects |
| `05_Deployment` | Loose game-layout output and portable deployment packages |
| `06_Current_Installation` | Known-good installation manifests and inventories |
| `07_Testing` | Test plans, results, compatibility notes, and regression data |
| `08_Tools` | Workshop-managed development tools |
| `09_Logs` | Structured deployment, restoration, and workshop logs |
| `10_Scripts` | PowerShell module, commands, and tests |
| `11_Utilities` | Supporting utilities |
| `12_Research` | Technical research and investigation notes |
| `13_Backups` | Deployment and pre-restore safety backups |
| `14_Templates` | Reusable project and configuration templates |
| `15_Sandbox` | Isolated experiments |
| `16_Profiles` | Installation and mod-set profiles |

## Workflow

```text
Archive -> Stage -> Library -> Deploy -> Validate -> Inventory
```

Git stores source and lightweight metadata. External 7z archives preserve
durable binary content; see [WorkshopBackup.md](WorkshopBackup.md).

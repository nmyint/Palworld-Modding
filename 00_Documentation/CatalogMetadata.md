# Remote Catalog Metadata

Missing local archives do not prevent the workshop from retaining installed
mods. For these records, the optional metadata module can query Nexus using a
previously reviewed Nexus mod ID:

```powershell
Get-PwNexusCatalogMetadataReport
```

The report compares the Nexus page name with the UE4SS folder name and labels
the result `Exact`, `Strong`, or `Review`. It also parses GitHub repository and
release links from the Nexus API description.

Hidden or deleted pages are reported as `ApiUnavailable` without stopping the
remaining checks.

The supported personal-key Nexus API does not provide a general mod-name search
endpoint. Therefore, a record without a Nexus ID is returned as
`NeedsNexusId`, with its folder name in `SearchTerm`. The workshop never assigns
an identity solely because two names look similar.

After reviewing the report, store the remote snapshot in the tracked catalog:

```powershell
Update-PwNexusCatalogMetadata
```

The same preview-and-apply workflow is available from the main menu under
**Catalog → Remote metadata**. Use **Catalog → Edit identity** to select a
catalog record, enter a Nexus ID, inspect the returned Nexus identity and
GitHub sources, and then apply reviewed display-name or installed-version
fields. GitHub URLs embedded in the Nexus description's BBCode are parsed into
normalized repository and release sources. Entering a replacement Nexus ID
replaces the record's previous ID after confirmation.

This adds `RemoteMetadata` containing the remote name, current page version,
summary, match quality, discovered GitHub sources, and retrieval time. It does
not change `InstalledVersion`, download a file, or modify the game.

# Nexus provenance and hash verification

The workshop records Nexus mod IDs, file IDs, versions, filenames, and source
URLs as provenance. Integrity is established independently with local SHA-256
hashes.

## API boundary

The Nexus API's downloadable-file metadata identifies archive files, but it does
not provide a public, authoritative SHA-256 for every downloaded archive. The
newer archive-content search can expose internal paths, names, extensions, and
sizes. Its documented fields do not expose hashes for individual Lua, DLL, PAK,
UTOC, UCAS, or configuration payloads.

Therefore:

- an original ZIP or 7z is SHA-256 hashed locally when present;
- every extracted or staging payload is SHA-256 hashed locally;
- curated 7z packages receive their own SHA-256;
- assembly and deployment re-hash files after every copy;
- Nexus identity metadata is not treated as proof of byte identity;
- customized configuration or scripts intentionally produce new local hashes.

This keeps Nexus useful for identity, versions, update checks, and download
provenance without claiming a remote hash guarantee the service does not expose.

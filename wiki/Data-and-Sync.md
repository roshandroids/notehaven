# Data and Sync

## Local database
Drift over SQLite (native on mobile/desktop, WASM on web). Tables: `notes`, `outbox`, `sync_state`. Schema is dumped to `app/drift_schemas/` for migration tests.

| Version | Change |
|---|---|
| 1 | notes |
| 2 | soft delete (`deletedAt`), `rev`, `clock`, `outbox`, `sync_state` |
| 3 | rich `content` column (old notes keep their plain body) |

Changing a table: bump `schemaVersion` in `app/lib/core/database/app_database.dart`, add an `onUpgrade` step, re-dump the schema, add a migration test.

## Sync
Engine and ports in `packages/notehaven_sync`; REST reference adapter in `notehaven_sync_rest`. Writes go to local DB and the outbox first, so the app works offline. Soft deletes propagate as tombstones. Tested against fakes only; no real backend ships. Protocol: [sync_protocol.md](https://github.com/roshandroids/notehaven/blob/main/documentation/sync_protocol.md), rationale: [ADR-0002](https://github.com/roshandroids/notehaven/blob/main/documentation/adr/0002-offline-first-sync.md).

# ADR-0002: Offline-first sync design

Status: accepted.

**Context:** notes must work offline and sync to a backend the template user chooses, with no vendor SDK in the app.

**Decision:**
- Drift stays the single local source of truth. Sync is a separate pure-Dart engine (`notehaven_sync`) behind two ports: `RemoteNoteStore` (the backend) and `LocalSyncStore` (implemented on Drift in `core/sync`).
- Outbox pattern: one queue row per note id, written in the same transaction as the note change; a per-note `rev` counter guards the acknowledgment against edits made during a push.
- The server issues the pull cursor; clients never use their own timestamps as a cursor.
- Deletes are soft (tombstones) so they can sync. Domain `Note`s never include tombstones.
- Conflicts: last-write-wins on a per-note millisecond `clock` (`updatedAt` in the wire format); a tie goes to the server copy. Delete and restore both advance the clock.
- Pushes are idempotent PUTs of the full note keyed by a client-generated UUID.
- Sync is off unless a remote is configured. Triggers: debounced after local writes, a 60 s timer, exponential backoff after failures (5 s up to 5 min).

**Why a separate `clock` column:** Drift stores `DateTime` with second precision by default, which would make two edits in the same second tie. `clock` is epoch milliseconds, forced strictly above the previous value for that note.

**Consequences / limits:**
- Whole-note last-write-wins: concurrent edits of different parts of one note lose one side. A real merge would need a CRDT or operational transform, and would change the protocol.
- Clock skew between devices can mis-order edits.
- Tombstones are never purged (shortcut).
- No connectivity or app-resume triggers yet (`SyncScheduler.requestSync` is the hook).
- Verified only against an in-memory fake server and a mocked HTTP server, not a real backend.

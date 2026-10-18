# Sync protocol

Notehaven syncs notes between the local Drift database and any backend that implements this small protocol. The app
never imports a vendor SDK: the engine (`packages/notehaven_sync`) talks to a `RemoteNoteStore` interface, and
`packages/notehaven_sync_rest` is a reference HTTP implementation of it.

## Model

A note on the wire (`SyncNote`, JSON, ISO-8601 UTC timestamps):

```json
{
  "id": "uuid-chosen-by-the-client",
  "title": "Groceries",
  "body": "milk",
  "createdAt": "2026-01-01T00:00:00.000Z",
  "updatedAt": "2026-01-01T00:05:00.000Z",
  "deletedAt": null,
  "content": "[{\"insert\":\"milk\\n\"}]"
}
```

- `updatedAt` is the conflict clock (millisecond precision). It must increase on every change, including delete and restore.
- `content` is **optional** and opaque: the rich-text editor's document (Quill Delta JSON, which may embed drawings), stored as a string. Servers must store it and return it unchanged and must not parse or rewrite it. `body` is always the plain-text version, so a server or client without a rich editor still works. Older clients omit `content`; a missing or `null` value means "plain-text note".
- `deletedAt` non-null means the note is deleted (a tombstone). Servers keep tombstones so other devices learn about deletes.

## Endpoints

### `GET {base}/notes/changes?limit=100&cursor=<opaque>`
Returns changes after `cursor` (omit it for the first pull), oldest first, tombstones included:

```json
{ "items": [ /* notes */ ], "nextCursor": "opaque-string", "hasMore": false }
```

- The **server issues the cursor** (for example a change sequence number). Clients store it and send it back unchanged; they never invent one from a timestamp, because device clocks drift.
- `hasMore: true` means call again with `nextCursor`. A server must advance the cursor when it says `hasMore`, or the client stops with an error.
- A note changed again after the cursor appears again in later pages.

### `PUT {base}/notes/{id}`
Body: a full note (including `content` when present). Creates or replaces the note. Servers should accept bodies of at least 512 KB because drawings live inside `content` (the app caps one drawing at 200 KB, but a note may hold several); a `413` is treated as a per-note rejection and the note stays queued. **Idempotent**: sending the same note twice changes nothing and must not create a new change entry.

Response `200`: the version the server now holds. If the server already holds a note with an `updatedAt` greater than or equal to the incoming one, it keeps its own and returns it (newer wins, a tie keeps the server copy).

## Errors

| HTTP | Meaning to the engine |
|---|---|
| 401, 403 | `auth`: stop the run, retry later (after token refresh) |
| 408, 425, 429, network failure, timeout | `network`: stop the run, retry with backoff |
| 400, 409, 413, 422 on `PUT` | `rejected`: skip this note, keep syncing the others, retry later |
| 5xx, malformed JSON, other | `server`: stop the run, retry with backoff |

Authentication is the host app's job: `RestRemoteNoteStore` takes a `headers` callback that is called before every request.

## Conflict rule

Last write wins on `updatedAt`; a tie goes to the server copy, so every device converges on the server's choice. On pull, a remote note replaces the local one when `remote.updatedAt >= local.updatedAt` (and drops any queued local change for it); otherwise the local note is kept and pushed.

Limits: it compares device-supplied clocks, so a device with a badly wrong clock can win or lose unfairly, and two edits to different fields of the same note do not merge (the later whole note wins). See ADR-0002.

## How the client stays correct

1. Every local write bumps the note's revision and queues it in the **same database transaction** (one queue entry per note).
2. Push sends the current note; after success the queue entry is cleared **only if the note's revision is unchanged**, so an edit made during the push is never lost.
3. Applying pulled data never queues anything (no echo), and the new cursor is saved in the same transaction as the pulled notes.
4. Push runs before pull so an older server copy cannot undo a local delete.
5. Restoring a deleted note stamps a new `updatedAt`, so the restore beats the earlier delete on every device.

## Implementing a backend

Any server that implements the two endpoints works. To write your own client instead of using HTTP, implement `RemoteNoteStore` (`pull`, `push`) and run the shared contract suite (`remoteStoreContract` in `package:notehaven_sync/testing.dart`) against it.

This repository has only been tested against an in-memory fake server (mock HTTP). It has not been run against Supabase, Firebase or any real service; a thin function or proxy in front of one of them that speaks this protocol is the intended route.

## Turning sync on

Sync is off by default (the template has no backend). Pass a remote when bootstrapping:

```dart
runApp(ProviderScope(
  overrides: await productionOverrides(
    remote: RestRemoteNoteStore(
      baseUrl: Uri.parse('https://api.example.com/v1'),
      client: http.Client(),
      headers: () async => {'authorization': 'Bearer ${await tokenProvider()}'},
    ),
  ),
  child: const App(),
));
```

(`notehaven_sync_rest` is not an app dependency yet; add it to `app/pubspec.yaml` first.)

# Roadmap

Goal: a complete, readable reference for a production Flutter app on all six platforms.

| Phase | Adds | Status |
|---|---|---|
| 0 | Workspace, layers, `Result`/`Failure`, boundary checker, CI, docs | done |
| 1 | Drift persistence, notes UI, themes and fonts, responsive split view, accessibility basics | done (web persistence unverified) |
| 2 | Auto sync local → remote: engine, REST reference adapter, Drift v2 migration (see [protocol](sync_protocol.md)) | done; tested against fakes only |
| 3 | Rich text editor with `flutter_quill` (or another established package), Markdown and PDF export | planned |
| 4 | Drawings: freehand sketch notes attached to a note (pen, eraser, colors, undo/redo, export as image/PDF) | planned |
| 5 | Voice dictation (speech-to-text), document capture/scan attached to a note | planned |
| 6 | Pro features: tags, pinning, folders, reminders, note lock, version history, attachments search | planned |
| 7 | Platform channels, FFI, DTD client, DevTools extension | planned |
| 8 | Release pipeline for all targets, crash reporting, structured logs | planned |

Decision: the editor will be an established package, not a custom engine (`Document_Platform` was ruled out as over-engineered).

Each phase ends with one visible result and any new decision recorded as an ADR.

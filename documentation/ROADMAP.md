# Roadmap

Goal: a complete, readable reference for a production Flutter app on all six platforms.

| Phase | Adds | Status |
|---|---|---|
| 0 | Workspace, layers, `Result`/`Failure`, boundary checker, CI, docs | done |
| 1 | Drift persistence, notes UI, themes and fonts, responsive split view, accessibility basics | done (web persistence unverified) |
| 2 | Auto sync local → remote (outbox, retry, conflicts) as a pure-Dart package | needs backend choice |
| 3 | Rich editor (Document Platform), Markdown and PDF export | needs the editor package to be public or published |
| 4 | Voice dictation (speech-to-text), document capture/scan attached to a note | planned |
| 5 | Pro features: tags, pinning, folders, reminders, note lock, version history, attachments search | planned |
| 6 | Platform channels, FFI, DTD client, DevTools extension | planned |
| 7 | Release pipeline for all targets, crash reporting, structured logs | planned |

Each phase ends with one visible result and any new decision recorded as an ADR.

# Roadmap

Goal: a complete, readable reference for a production Flutter app on all six platforms.

| Phase | Adds |
|---|---|
| 0 (done) | Workspace, layers, `Result`/`Failure`, boundary checker, CI, docs |
| 1 | Drift persistence, form validation, go_router deep links, localization, dark mode, fake REST API |
| 2 | Offline-first sync (outbox, retry, conflicts) as a pure-Dart package, isolates for heavy work |
| 3 | Slivers, advanced animation, custom scroll physics, profiling with a frame-time budget |
| 4 | `CustomPainter` markup/chart toolkit, custom `RenderBox`/`RenderSliver`, shaders, accessibility |
| 5 | Platform channels, Pigeon, FFI with web stub, adaptive desktop UI |
| 6 | Dart Tooling Daemon client, DevTools extension |
| 7 | Release pipeline for all targets, crash reporting, structured logs |

Each phase ends with one visible result and any new decision recorded as an ADR.

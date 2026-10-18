# Architecture

Feature-first layers with Riverpod (hand-written `Notifier`/`AsyncNotifier`) and go_router. Pub workspace.

```
app/lib/
  app/        composition root: bootstrap, router, theme, adaptive_shell, feedback_wiring
  core/       database (Drift), sync wiring
  features/   notes/, settings/  -> domain / data / presentation
  shared/     feedback (haptics, sounds), layout, widgets
packages/
  notehaven_core       Result, Failure (pure Dart)
  notehaven_sync       sync engine + ports (pure Dart)
  notehaven_sync_rest  HTTP reference adapter
```

## Rules (enforced by `dart run tool/bin/check_boundaries.dart`)
- `domain` imports no Flutter, `data` or `presentation`.
- `presentation` uses `domain` interfaces, never `data`.
- A feature never imports another feature or `app/`.
- Pure packages never import Flutter; sync packages never import Drift; packages never import the app.
- Only `app/lib/app/` binds interfaces to implementations.

## Conventions
- Expected failures return `Result<T>`/`Failure`; exceptions are for bugs ([ADR-0001](https://github.com/roshandroids/notehaven/blob/main/documentation/adr/0001-result-instead-of-exceptions.md)).
- Check `ref.mounted` after every `await` that sets state.
- Any non-obvious decision gets an ADR in `documentation/adr/`.

Source of truth: [AGENTS.md](https://github.com/roshandroids/notehaven/blob/main/AGENTS.md), `documentation/ARCHITECTURE_DECISION.md`, `documentation/dependency_rules.md`.

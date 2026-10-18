# Architecture decision

Feature-first layered architecture on Riverpod, with rules checked by a script.

## Shape
```
app/lib/app/                 composition root
app/lib/features/<f>/domain  models, repository interfaces, (use cases when needed)
app/lib/features/<f>/data    repository implementations, DTOs
app/lib/features/<f>/presentation  screens, widgets, Notifier controllers
packages/notehaven_core        pure Dart: Result, Failure
tool/                        boundary checker
```

## Why
- Layers follow the [official Flutter app architecture guide](https://docs.flutter.dev/app-architecture/guide)
  (UI / data, optional domain) and the feature-first Riverpod layout popularised by Code With Andrea.
- Rules are code, not convention: `tool/bin/check_boundaries.dart` fails CI on a violation.
- `Result<T>` makes expected failures part of the type (ADR-0001).

## Not included yet (planned, see ROADMAP.md)
Persistence (Drift), sync, auth, networking, localization, flavors. Each lands with its own ADR.

# AGENTS.md — rules for AI coding agents and humans

Single source of truth. `CLAUDE.md` and other tool files only point here.

## Before you change anything
1. Read `documentation/ARCHITECTURE_DECISION.md` and `documentation/dependency_rules.md`.
2. Follow the existing pattern for what you add (see `app/lib/features/notes`). If two files disagree, ask.
3. Toolchain: always `fvm flutter` / `fvm dart` (pinned in `.fvmrc`).

## Gate (must pass before you finish)
```bash
scripts/verify.sh   # format, analyze, boundary check, all tests
```

## Layout
- `app/lib/app/` composition root (bootstrap, router, theme). Only place binding interfaces to implementations.
- `app/lib/features/<f>/{domain,data,presentation}/` one folder per feature.
- `packages/notehaven_core` pure Dart (Result, Failure). Never imports Flutter.
- `tool/` repo tooling (`check_boundaries`).

## Rules (enforced by `tool/bin/check_boundaries.dart`)
- `domain` imports no Flutter, `data`, or `presentation`.
- `presentation` uses `domain` interfaces, never `data`.
- A feature never imports another feature or `app/`.
- Packages never import the app; `notehaven_core` never imports Flutter.

## Conventions
- Hand-written Riverpod `Notifier`/`AsyncNotifier`; check `ref.mounted` after every `await` that sets state.
- Expected failures use `Result<T>`/`Failure`; exceptions are for bugs.
- Add an ADR (`documentation/adr/`) for any non-obvious decision; update docs in the same change.
- Doc comments explain behavior and data flow, not what the signature already says.
- Do not add dependencies for a few lines of code.

# AGENTS.md — rules for AI coding agents and humans

Single source of truth. `CLAUDE.md` and other tool files only point here.

## Before you change anything
1. Read `documentation/ARCHITECTURE_DECISION.md` and `documentation/dependency_rules.md`.
2. Follow the existing pattern for what you add (see `app/lib/features/notes`). If two files disagree, ask.
3. Toolchain: always `fvm flutter` / `fvm dart` (pinned in `.fvmrc`).

## Workflow: features by request, changes by PR
- `main` is protected: no direct pushes, no deletion; only the repo owner may bypass (force-push).
- A feature is added only for an open **feature request** issue (`.github/ISSUE_TEMPLATE/feature_request.md`). No request, no feature; agents must ask the user to file or name one first.
- All changes land through a pull request from a branch named after the issue (`feat/<n>-short-name`, `fix/...`), linking the issue (`Closes #n`), with the `verify` CI check green. Never push to `main`; never commit unless asked.
- Heavy builds (macOS, Windows, Android) are manual: `release-builds.yaml`. The website deploys to notehaven.rsprojects.dev via `pages.yaml` on every push to `main`.

## Gate (must pass before you finish)
```bash
scripts/verify.sh   # format, analyze, boundary check, all tests
```

## Layout
- `app/lib/app/` composition root (bootstrap, router, theme). Only place binding interfaces to implementations.
- `app/lib/features/<f>/{domain,data,presentation}/` one folder per feature.
- `packages/notehaven_core` pure Dart (Result, Failure). Never imports Flutter.
- `packages/notehaven_sync` pure Dart sync engine + ports; `notehaven_sync_rest` HTTP reference adapter. Never import Flutter or Drift.
- `tool/` repo tooling (`check_boundaries`).

## Rules (enforced by `tool/bin/check_boundaries.dart`)
- `domain` imports no Flutter, `data`, or `presentation`.
- `presentation` uses `domain` interfaces, never `data`.
- A feature never imports another feature or `app/`.
- Packages never import the app; pure packages (`notehaven_core`, `notehaven_sync`, `notehaven_sync_rest`) never import Flutter, and the sync packages never import Drift.

## Conventions
- Hand-written Riverpod `Notifier`/`AsyncNotifier`; check `ref.mounted` after every `await` that sets state.
- Expected failures use `Result<T>`/`Failure`; exceptions are for bugs.
- Add an ADR (`documentation/adr/`) for any non-obvious decision; update docs in the same change.
- Doc comments explain behavior and data flow, not what the signature already says.
- Do not add dependencies for a few lines of code.

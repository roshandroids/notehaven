# Notehaven

An offline-first notes app and reference architecture for Flutter. Targets iOS, Android, web, macOS, Windows and Linux.
Use it as a **GitHub template** for your own apps, or read it to learn a layered, rule-checked Flutter structure.

> Status: Phase 0 — structure, rules and CI are in place; features land phase by phase (see [ROADMAP](documentation/ROADMAP.md)).

## What you get
- Pub workspace: `app/`, `packages/notehaven_core` (pure Dart), `tool/`.
- Feature-first layers (`domain` / `data` / `presentation`) with Riverpod and go_router.
- Architecture rules enforced by code: `dart run tool/bin/check_boundaries.dart`.
- One gate for humans and CI: `scripts/verify.sh`.
- Agent-ready: `AGENTS.md` is the single instruction file; `CLAUDE.md` points to it.
- CI builds web, Android, Linux, macOS, iOS (no codesign) and Windows.

## Quick start
```bash
fvm install            # Flutter 3.44.8 from .fvmrc
fvm flutter pub get
scripts/verify.sh
cd app && fvm flutter run
```

## Use as a template
1. Click **Use this template** on GitHub.
2. Run `scripts/rename.sh my_app "My App"` (renames Dart packages, docs and display name in code; platform folders keep `org.example` ids, binary names and labels until you rename them).
3. Run `scripts/verify.sh`.

## Docs
[Architecture](documentation/ARCHITECTURE_DECISION.md) · [Dependency rules](documentation/dependency_rules.md) · [Testing](documentation/testing.md) · [ADRs](documentation/adr/) · [Contributing](CONTRIBUTING.md)

MIT licensed.

## Legal notes
- Code is MIT-licensed (see `LICENSE`); replace the copyright holder with yours before publishing.
- "Notehaven" and the placeholder app id `org.example` are not trademark-cleared or registered anywhere. Search the
  USPTO/EUIPO/CIPO databases and the App Store / Google Play before shipping under this name, and set your own
  reverse-DNS app id.
- Contains no third-party assets (fonts, icons, images). Dependencies keep their own licenses (`flutter pub deps`).
- Not affiliated with Google, Flutter, or any employer. Do not add code, data or documents from an employer's
  projects; confirm your employment agreement allows publishing personal work.

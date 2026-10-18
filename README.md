# Notehaven

An offline-first notes app and reference architecture for Flutter. Targets iOS, Android, web, macOS, Windows and Linux.
Use it as a **GitHub template** for your own apps, or read it to learn a layered, rule-checked Flutter structure.

> Status: Phase 0 — structure, rules and CI are in place; features land phase by phase (see [ROADMAP](documentation/ROADMAP.md)).

## Features
- Notes: rich text (flutter_quill), freehand drawings inside notes, delete with undo, copy, live search, masonry grid, swipe actions, word count.
- Appearance: every FlexColorScheme theme (50+), light/dark/system, any Google Font with live previews.
- Local SQLite (Drift) with the schema dumped for migrations (`app/drift_schemas/`).
- Backend-agnostic auto sync (off until you configure a backend): engine, REST reference adapter, soft deletes, outbox ([protocol](documentation/sync_protocol.md)).
- Feedback: haptics (phones/tablets), optional UI sounds (off by default, generated in code), undo snackbars, long-press/right-click note menu, animated empty state, sync icon and drawing thumbnails; all switchable in Appearance ([ADR-0004](documentation/adr/0004-feedback-haptics-sounds-motion.md)).
- Keyboard shortcuts: Ctrl/Cmd+N new note, Ctrl/Cmd+S save, Ctrl/Cmd+, appearance.
- Responsive: one pane on phones, list + editor side by side from 900 px wide.
- Accessibility: screen-reader labels and actions, tap-target tests, reduce-motion support ([details](documentation/accessibility.md)).

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
(cd app && fvm dart run build_runner build)   # generates Drift code (*.g.dart, not committed)
scripts/verify.sh
cd app && fvm flutter run
```

## Use as a template
1. Click **Use this template** on GitHub.
2. Run `scripts/rename.sh my_app "My App"` (renames Dart packages, docs and display name in code; platform folders keep `org.example` ids, binary names and labels until you rename them).
3. Run `scripts/verify.sh`.

## Web
`app/web/` contains `sqlite3.wasm` (sqlite3 3.5.2) and `drift_worker.js` (drift 2.34.0), downloaded from the official
[sqlite3.dart](https://github.com/simolus3/sqlite3.dart/releases) and [drift](https://github.com/simolus3/drift/releases)
releases. When you change the pinned `drift`/`sqlite3` versions, replace both files with the matching release
(see the [Drift web docs](https://drift.simonbinder.eu/platforms/web/)).

Known issue: in the Claude desktop app's embedded browser the web build renders and themes correctly but the database never
opened (the worker never requested `sqlite3.wasm`). Not yet tested in Chrome/Safari/Firefox; treat web persistence as unverified.

## Docs
[Sync protocol](documentation/sync_protocol.md) · [Rich text & drawings](documentation/adr/0003-rich-text-and-drawings.md) · [Performance](documentation/performance.md) · [Accessibility](documentation/accessibility.md) ·
[Architecture](documentation/ARCHITECTURE_DECISION.md) · [Dependency rules](documentation/dependency_rules.md) · [Testing](documentation/testing.md) · [ADRs](documentation/adr/) · [Contributing](CONTRIBUTING.md)

MIT licensed.

## Legal notes
- Code is MIT-licensed (see `LICENSE`); replace the copyright holder with yours before publishing.
- "Notehaven" and the placeholder app id `org.example` are not trademark-cleared or registered anywhere. Search the
  USPTO/EUIPO/CIPO databases and the App Store / Google Play before shipping under this name, and set your own
  reverse-DNS app id.
- Bundles `sqlite3.wasm` (SQLite is public domain; sqlite3.dart is MIT) and `drift_worker.js` (drift, MIT). UI sounds are short tones synthesized in code at runtime (`app/lib/shared/feedback/tones.dart`), so no audio files are bundled; the `audioplayers` package (MIT) only plays them. No other third-party assets. Fonts are downloaded at runtime from Google Fonts (open-source licenses, mostly
  OFL) when a user picks one; this sends a request to Google's font servers, so mention it in your privacy policy.
  Dependencies keep their own licenses (`flutter pub deps`).
- Not affiliated with Google, Flutter, or any employer. Do not add code, data or documents from an employer's
  projects; confirm your employment agreement allows publishing personal work.

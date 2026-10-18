# Getting Started

Flutter is pinned in `.fvmrc` (3.44.8). Always use `fvm flutter` / `fvm dart`.

```bash
fvm install
fvm flutter pub get
(cd app && fvm dart run build_runner build)   # Drift code; *.g.dart is not committed
scripts/verify.sh                              # format, analyze, boundaries, tests
cd app && fvm flutter run
```

## Layout
- `app/` Flutter app. `packages/` pure Dart (`notehaven_core`, `notehaven_sync`, `notehaven_sync_rest`). `tool/` repo tooling. `scripts/` `verify.sh`, `rename.sh`.
- Use as a template: **Use this template** on GitHub, then `scripts/rename.sh my_app "My App"`.

## Web notes
`app/web/` holds `sqlite3.wasm` and `drift_worker.js`; replace both when you change the pinned `drift`/`sqlite3` versions. Web persistence is unverified outside the Claude desktop browser.

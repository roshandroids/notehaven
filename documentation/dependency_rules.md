# Dependency rules

Checked by `dart run tool/bin/check_boundaries.dart` (also run by `scripts/verify.sh` and CI).

| # | Rule |
|---|---|
| 1 | `domain` imports no Flutter, no `data`, no `presentation` |
| 2 | A feature never imports another feature |
| 3 | A feature never imports `app/` |
| 4 | `presentation` never imports `data`; it uses `domain` interfaces bound in `app/bootstrap.dart` |
| 5 | Packages never import the app |
| 6 | `notehaven_core` never imports Flutter |

Shared code needed by two features moves to `shared/` (app-level) or a package. There are no named exceptions.
The checker reads `import`/`export` lines only; it does not catch rules broken through generated code.

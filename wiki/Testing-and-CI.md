# Testing and CI

## The gate
```bash
scripts/verify.sh   # format, analyze, boundary check, all tests
```
CI runs the same script: `FLUTTER=flutter DART=dart scripts/verify.sh`.

## Tests
- `packages/*`, `tool`: `dart test`. `app`: `flutter test` with `ProviderScope` overrides and the in-memory repositories.
- A `Notifier` doing async work in `build()` must be kept alive with `container.listen` in `ProviderContainer` tests.

## Workflows (`.github/workflows/`)
| File | Trigger | Does |
|---|---|---|
| `ci.yaml` | PR / push | `verify` + web build |
| `pages.yaml` | push to `main`, manual | verify, build web, deploy to GitHub Pages |
| `release-builds.yaml` | manual only | macOS, Windows, Android builds (kept manual to save free-tier minutes) |

## Protected `main`
Ruleset `protect-main`: no deletion, no force-push, PR required, `verify` check must pass. Only the repo owner (admin) can bypass.

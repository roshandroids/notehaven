# Contributing

1. **No feature without a request.** Open a feature request issue (template in `.github/ISSUE_TEMPLATE/`).
2. Branch from `main`: `feat/<n>-short-name` or `fix/...`.
3. Run `scripts/verify.sh` until green.
4. Open a PR using the template; link the issue (`Closes #n`). The `verify` check must pass.
5. Never push to `main`.

Conventions: follow the existing feature pattern (`features/notes`), no dependency for a few lines of code, ADR for non-obvious decisions, update docs in the same change. Full rules: [AGENTS.md](https://github.com/roshandroids/notehaven/blob/main/AGENTS.md).

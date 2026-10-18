# Testing

- `packages/notehaven_core`, `tool`: `dart test`.
- `app`: `flutter test` (widget tests use `ProviderScope` overrides with the in-memory repository).
- A `Notifier` that does async work in `build()` must be kept alive with `container.listen` in `ProviderContainer` tests, not a bare `read`.
- Run everything with `scripts/verify.sh`.

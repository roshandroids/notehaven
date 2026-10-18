# ADR-0001: Result<T> instead of exceptions for expected failures

Status: accepted.

**Context:** repositories fail in expected ways (validation, offline, storage).
**Decision:** repositories return `Result<T>` (`Ok` / `Err(Failure)`); exceptions signal bugs only.
**Consequences:** callers must handle failure (pattern matching, exhaustive); slightly more code per call.

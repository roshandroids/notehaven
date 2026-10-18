/// Expected, typed failure carried by [Result]. Exceptions are for bugs only.
sealed class Failure {
  const Failure(this.message);

  /// Human-readable description; never shown to users without localization.
  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// Input rejected by validation.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Remote call failed (offline, timeout, non-2xx).
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Local persistence failed.
final class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

/// Anything not mapped to a more specific failure.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}

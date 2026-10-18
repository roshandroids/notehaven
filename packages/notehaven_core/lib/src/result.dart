import 'failure.dart';

/// Success value or [Failure]; use pattern matching to consume it.
sealed class Result<T> {
  const Result();

  /// Maps both cases to one value.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

/// Successful [Result].
final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

/// Failed [Result].
final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

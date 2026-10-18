import 'package:notehaven_core/notehaven_core.dart';
import 'package:test/test.dart';

void main() {
  test('fold returns the Ok branch', () {
    const Result<int> r = Ok(2);
    expect(r.fold((v) => v * 2, (_) => -1), 4);
  });

  test('fold returns the Err branch', () {
    const Result<int> r = Err(ValidationFailure('bad'));
    expect(r.fold((_) => 'ok', (f) => f.message), 'bad');
  });
}

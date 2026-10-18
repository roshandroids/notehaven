import 'package:notehaven_sync/notehaven_sync.dart';
import 'package:test/test.dart';

SyncNote n(int second, {bool deleted = false, String title = 't'}) => SyncNote(
  id: 'a',
  title: title,
  body: 'b',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 1, 1, 0, 0, second),
  deletedAt: deleted ? DateTime.utc(2026, 1, 1, 0, 0, second) : null,
);

void main() {
  group('SyncNote json', () {
    test('round-trips including tombstones', () {
      for (final original in [n(1), n(2, deleted: true)]) {
        final back = SyncNote.fromJson(original.toJson());
        expect(back, original);
        expect(back.isDeleted, original.isDeleted);
      }
    });

    test('malformed payloads throw FormatException', () {
      expect(() => SyncNote.fromJson({'id': 1}), throwsFormatException);
      expect(
        () => SyncNote.fromJson({
          'id': 'a',
          'title': 't',
          'body': 'b',
          'createdAt': 'not a date',
          'updatedAt': 'x',
        }),
        throwsFormatException,
      );
    });
  });

  group('resolveConflict', () {
    test('unknown local note applies the remote', () {
      expect(
        resolveConflict(local: null, remote: n(1)),
        ConflictResolution.applyRemote,
      );
    });
    test('newer remote wins', () {
      expect(
        resolveConflict(local: n(1), remote: n(2)),
        ConflictResolution.applyRemote,
      );
    });
    test('older remote loses', () {
      expect(
        resolveConflict(local: n(5), remote: n(2)),
        ConflictResolution.keepLocal,
      );
    });
    test('a tie goes to the remote', () {
      expect(
        resolveConflict(
          local: n(3, title: 'x'),
          remote: n(3, title: 'y'),
        ),
        ConflictResolution.applyRemote,
      );
    });
  });
}

/// Fakes plus the shared contract suite for [RemoteNoteStore].
///
/// Import from tests only. Run [remoteStoreContract] against any adapter to
/// prove it behaves like a backend the engine can trust.
library;

import 'package:test/test.dart';

import 'notehaven_sync.dart';

export 'fakes.dart';

/// Shared behavior every [RemoteNoteStore] must have. [create] must return a
/// fresh, empty backend each call.
void remoteStoreContract(String name, RemoteNoteStore Function() create) {
  group('RemoteNoteStore contract: $name', () {
    late RemoteNoteStore remote;
    setUp(() => remote = create());

    SyncNote note(
      String id,
      int second, {
      String title = 't',
      bool deleted = false,
    }) {
      final at = DateTime.utc(2026, 1, 1, 0, 0, second);
      return SyncNote(
        id: id,
        title: title,
        body: 'b',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: at,
        deletedAt: deleted ? at : null,
      );
    }

    test('empty backend pulls nothing', () async {
      final page = await remote.pull();
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('push then pull returns the note and a cursor', () async {
      final stored = await remote.push(note('a', 1));
      expect(stored, note('a', 1));
      final page = await remote.pull();
      expect(page.items, [note('a', 1)]);
      expect(page.nextCursor, isNotNull);
      final again = await remote.pull(cursor: page.nextCursor);
      expect(again.items, isEmpty);
    });

    test('pushing the same note twice is idempotent', () async {
      await remote.push(note('a', 1));
      final first = await remote.pull();
      await remote.push(note('a', 1));
      final second = await remote.pull(cursor: first.nextCursor);
      expect(second.items, isEmpty);
    });

    test('a newer server version wins over an older push', () async {
      await remote.push(note('a', 5, title: 'new'));
      final stored = await remote.push(note('a', 1, title: 'old'));
      expect(stored.title, 'new');
    });

    test('rich content is stored and returned unchanged', () async {
      final withContent = SyncNote(
        id: 'rich',
        title: 't',
        body: 'b',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
        content: '[{"insert":"hello\\n"}]',
      );
      final stored = await remote.push(withContent);
      expect(stored.content, withContent.content);
      final page = await remote.pull();
      expect(page.items.single.content, withContent.content);
    });

    test('tombstones round-trip', () async {
      await remote.push(note('a', 1, deleted: true));
      final page = await remote.pull();
      expect(page.items.single.isDeleted, isTrue);
    });

    test('updates reappear after the cursor', () async {
      await remote.push(note('a', 1));
      await remote.push(note('b', 2));
      final first = await remote.pull();
      await remote.push(note('a', 3, title: 'edited'));
      final next = await remote.pull(cursor: first.nextCursor);
      expect(next.items.map((n) => n.title), ['edited']);
    });

    test('pagination covers every change exactly once', () async {
      for (var i = 0; i < 5; i++) {
        await remote.push(note('n$i', i + 1));
      }
      final seen = <String>[];
      String? cursor;
      var pages = 0;
      while (true) {
        final page = await remote.pull(cursor: cursor, limit: 2);
        seen.addAll(page.items.map((n) => n.id));
        cursor = page.nextCursor;
        pages++;
        if (!page.hasMore) break;
      }
      expect(seen..sort(), ['n0', 'n1', 'n2', 'n3', 'n4']);
      expect(pages, 3);
    });
  });
}

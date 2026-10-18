import 'package:notehaven_sync/notehaven_sync.dart';
import 'package:notehaven_sync/testing.dart';
import 'package:test/test.dart';

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

void main() {
  late FakeRemoteNoteStore remote;
  late InMemoryLocalSyncStore local;
  late SyncEngine engine;

  setUp(() {
    remote = FakeRemoteNoteStore();
    local = InMemoryLocalSyncStore();
    engine = SyncEngine(local: local, remote: remote, pageSize: 2);
  });

  remoteStoreContract('FakeRemoteNoteStore', FakeRemoteNoteStore.new);

  test('offline create syncs later and clears the queue', () async {
    local.write(note('a', 1));
    remote.offline = true;
    final failed = await engine.syncOnce();
    expect(failed.ok, isFalse);
    expect(local.isQueued('a'), isTrue);

    remote.offline = false;
    final report = await engine.syncOnce();
    expect(report.ok, isTrue);
    expect(report.pushed, 1);
    expect(remote.get('a'), note('a', 1));
    expect(local.isQueued('a'), isFalse);
  });

  test(
    'delete then restore during an outage pushes only the final state',
    () async {
      local
        ..write(note('a', 1))
        ..write(note('a', 2, deleted: true)) // deleted
        ..write(note('a', 3, title: 'back')); // restored with a newer clock
      expect(local.queuedCount, 1);
      await engine.syncOnce();
      expect(remote.get('a')!.isDeleted, isFalse);
      expect(remote.get('a')!.title, 'back');
      expect(remote.pushCalls, 1);
    },
  );

  test('an edit made while a push is in flight is not lost', () async {
    local.write(note('a', 1, title: 'v1'));
    remote.onPushStored = (_) {
      remote.onPushStored = null;
      local.write(note('a', 2, title: 'v2')); // user edits during the push
    };
    await engine.syncOnce();
    // The first ack must not have cleared the newer edit; the same run's push
    // loop sends it, so the server ends with v2 and the queue is empty.
    expect(remote.get('a')!.title, 'v2');
    expect(local.isQueued('a'), isFalse);
    expect(local.note('a')!.title, 'v2');
  });

  test('a lost response is retried without duplicating', () async {
    local.write(note('a', 1));
    remote.loseNextPushResponse = true;
    final first = await engine.syncOnce();
    expect(first.ok, isFalse);
    expect(local.isQueued('a'), isTrue);
    final seqAfterStore = remote.sequence;

    final second = await engine.syncOnce();
    expect(second.ok, isTrue);
    expect(local.isQueued('a'), isFalse);
    expect(
      remote.sequence,
      seqAfterStore,
      reason: 'retry must not change the server',
    );
  });

  test('a newer remote tombstone replaces an older local edit', () async {
    local.write(note('a', 1, title: 'local'));
    await engine.syncOnce();
    remote.seed(note('a', 9, deleted: true)); // other device deleted it later
    await engine.syncOnce();
    expect(local.note('a')!.isDeleted, isTrue);
    expect(local.isQueued('a'), isFalse);
  });

  test('a newer local edit beats an older remote tombstone', () async {
    remote.seed(note('a', 1, deleted: true));
    local.write(note('a', 5, title: 'mine'));
    // Pull happens after push, but the push already sends the newer edit.
    await engine.syncOnce();
    expect(remote.get('a')!.title, 'mine');
    expect(remote.get('a')!.isDeleted, isFalse);
    expect(local.note('a')!.title, 'mine');
  });

  test('pull spans several pages and saves the final cursor', () async {
    for (var i = 1; i <= 5; i++) {
      remote.seed(note('n$i', i));
    }
    final report = await engine.syncOnce();
    expect(report.pulled, 5);
    for (var i = 1; i <= 5; i++) {
      expect(local.note('n$i'), isNotNull);
    }
    expect(local.cursor, remote.sequence.toString());
    final again = await engine.syncOnce();
    expect(again.pulled, 0);
  });

  test('a rejected note does not block the others', () async {
    remote.rejectIds.add('bad');
    local
      ..write(note('bad', 1))
      ..write(note('good', 2));
    final report = await engine.syncOnce();
    expect(report.ok, isTrue);
    expect(report.rejected, 1);
    expect(remote.get('good'), isNotNull);
    expect(local.isQueued('bad'), isTrue);
    expect(local.isQueued('good'), isFalse);
  });

  test('two devices converge', () async {
    final localB = InMemoryLocalSyncStore();
    final engineB = SyncEngine(local: localB, remote: remote);
    local.write(note('a', 1, title: 'from A'));
    await engine.syncOnce();
    await engineB.syncOnce();
    expect(localB.note('a')!.title, 'from A');

    localB.write(note('a', 5, title: 'B edits'));
    await engineB.syncOnce();
    await engine.syncOnce();
    expect(local.note('a')!.title, 'B edits');
  });

  test('concurrent syncOnce calls share one run', () async {
    local.write(note('a', 1));
    final results = await Future.wait([engine.syncOnce(), engine.syncOnce()]);
    expect(identical(results[0], results[1]), isTrue);
    expect(remote.pushCalls, 1);
  });

  test('auth failure stops the run and keeps the queue', () async {
    local.write(note('a', 1));
    remote.failNextPush = const RemoteException(RemoteFailureKind.auth, '401');
    final report = await engine.syncOnce();
    expect(report.ok, isFalse);
    expect((report.error! as RemoteException).kind, RemoteFailureKind.auth);
    expect(local.isQueued('a'), isTrue);
  });
}

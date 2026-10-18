import 'package:fake_async/fake_async.dart';
import 'package:notehaven_sync/notehaven_sync.dart';
import 'package:notehaven_sync/testing.dart';
import 'package:test/test.dart';

void main() {
  late FakeRemoteNoteStore remote;
  late InMemoryLocalSyncStore local;
  late SyncScheduler scheduler;

  SyncNote note(int second) => SyncNote(
    id: 'a',
    title: 't',
    body: 'b',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026, 1, 1, 0, 0, second),
  );

  setUp(() {
    remote = FakeRemoteNoteStore();
    local = InMemoryLocalSyncStore();
    scheduler = SyncScheduler(SyncEngine(local: local, remote: remote));
  });

  test('start syncs immediately, then on the interval', () {
    fakeAsync((async) {
      local.write(note(1));
      scheduler.start();
      async.flushMicrotasks();
      async.elapse(Duration.zero);
      expect(remote.pushCalls, 1);

      local.write(note(2));
      async.elapse(const Duration(seconds: 59));
      expect(remote.pushCalls, 1);
      async.elapse(const Duration(seconds: 2));
      expect(remote.pushCalls, 2);
      scheduler.stop();
    });
  });

  test('requestSync debounces bursts into one run', () {
    fakeAsync((async) {
      scheduler.start();
      async.elapse(Duration.zero);
      local.write(note(1));
      for (var i = 0; i < 5; i++) {
        scheduler.requestSync();
        async.elapse(const Duration(milliseconds: 500));
      }
      expect(remote.pushCalls, 0, reason: 'still inside the debounce window');
      async.elapse(const Duration(seconds: 2));
      expect(remote.pushCalls, 1);
      scheduler.stop();
    });
  });

  test('failures back off exponentially and recover', () {
    fakeAsync((async) {
      remote.offline = true;
      scheduler.start();
      async.elapse(Duration.zero);
      expect(scheduler.status.state, SyncState.failed);
      expect(scheduler.status.consecutiveFailures, 1);

      async.elapse(const Duration(seconds: 5)); // 1st backoff: 5 s
      expect(scheduler.status.consecutiveFailures, 2);
      async.elapse(const Duration(seconds: 9)); // 2nd backoff: 10 s, not yet
      expect(scheduler.status.consecutiveFailures, 2);
      async.elapse(const Duration(seconds: 2));
      expect(scheduler.status.consecutiveFailures, 3);

      remote.offline = false;
      async.elapse(const Duration(seconds: 20)); // 3rd backoff: 20 s
      expect(scheduler.status.state, SyncState.idle);
      expect(scheduler.status.consecutiveFailures, 0);
      scheduler.stop();
    });
  });

  test('stop cancels pending timers', () {
    fakeAsync((async) {
      scheduler.start();
      async.elapse(Duration.zero);
      scheduler.stop();
      local.write(note(1));
      async.elapse(const Duration(minutes: 10));
      expect(remote.pushCalls, 0);
    });
  });
}

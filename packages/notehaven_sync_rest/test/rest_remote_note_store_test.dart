import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notehaven_sync/notehaven_sync.dart';
import 'package:notehaven_sync/testing.dart';
import 'package:notehaven_sync_rest/notehaven_sync_rest.dart';
import 'package:test/test.dart';

final _base = Uri.parse('https://api.test/v1');

/// Minimal server implementing `documentation/sync_protocol.md` on top of the
/// in-memory fake, so the adapter is tested against real wire behavior.
MockClient serverFor(FakeRemoteNoteStore store, {List<http.BaseRequest>? log}) {
  return MockClient((request) async {
    log?.add(request);
    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
    try {
      final segments = request.url.pathSegments;
      if (request.method == 'GET' && segments.join('/') == 'v1/notes/changes') {
        final page = await store.pull(
          cursor: request.url.queryParameters['cursor'],
          limit: int.parse(request.url.queryParameters['limit']!),
        );
        return json({
          'items': [for (final n in page.items) n.toJson()],
          'nextCursor': page.nextCursor,
          'hasMore': page.hasMore,
        });
      }
      if (request.method == 'PUT' &&
          segments.length == 3 &&
          segments[1] == 'notes') {
        final note = SyncNote.fromJson(
          (jsonDecode(request.body) as Map).cast<String, Object?>(),
        );
        return json((await store.push(note)).toJson());
      }
      return http.Response('not found', 404);
    } on RemoteException catch (e) {
      throw switch (e.kind) {
        RemoteFailureKind.network => http.ClientException(e.message),
        _ => StateError('unmapped'),
      };
    }
  });
}

SyncNote note(String id, {int second = 1}) => SyncNote(
  id: id,
  title: 't',
  body: 'b',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 1, 1, 0, 0, second),
);

RestRemoteNoteStore storeWith(
  MockClient client, {
  Duration? timeout,
  Future<Map<String, String>> Function()? headers,
}) => RestRemoteNoteStore(
  baseUrl: _base,
  client: client,
  timeout: timeout ?? const Duration(seconds: 5),
  headers: headers,
);

void main() {
  remoteStoreContract(
    'RestRemoteNoteStore over a mock HTTP server',
    () => storeWith(serverFor(FakeRemoteNoteStore())),
  );

  group('RestRemoteNoteStore', () {
    test('sends auth headers from the callback on every request', () async {
      final log = <http.BaseRequest>[];
      var token = 'one';
      final remote = storeWith(
        serverFor(FakeRemoteNoteStore(), log: log),
        headers: () async => {'authorization': 'Bearer $token'},
      );
      await remote.pull();
      token = 'two';
      await remote.push(note('a'));
      expect(log[0].headers['authorization'], 'Bearer one');
      expect(log[1].headers['authorization'], 'Bearer two');
    });

    test('encodes ids in the path and keeps the base path', () async {
      final log = <http.BaseRequest>[];
      final remote = RestRemoteNoteStore(
        baseUrl: Uri.parse('https://api.test/v1/'),
        client: serverFor(FakeRemoteNoteStore(), log: log),
      );
      await remote.push(note('a/b c'));
      expect(log.single.url.toString(), 'https://api.test/v1/notes/a%2Fb%20c');
    });

    test('maps HTTP statuses to failure kinds', () async {
      Future<RemoteFailureKind> kindFor(int status, {bool push = true}) async {
        final remote = storeWith(
          MockClient((_) async => http.Response('', status)),
        );
        try {
          if (push) {
            await remote.push(note('a'));
          } else {
            await remote.pull();
          }
        } on RemoteException catch (e) {
          return e.kind;
        }
        fail('expected a RemoteException for $status');
      }

      expect(await kindFor(401), RemoteFailureKind.auth);
      expect(await kindFor(403), RemoteFailureKind.auth);
      expect(await kindFor(429), RemoteFailureKind.network);
      expect(await kindFor(408), RemoteFailureKind.network);
      expect(await kindFor(422), RemoteFailureKind.rejected);
      expect(await kindFor(409), RemoteFailureKind.rejected);
      expect(await kindFor(500), RemoteFailureKind.server);
      expect(await kindFor(503), RemoteFailureKind.server);
      // A 4xx on pull is not a per-note rejection.
      expect(await kindFor(422, push: false), RemoteFailureKind.server);
    });

    test('a client error becomes a network failure', () async {
      final remote = storeWith(
        MockClient(
          (_) async => throw http.ClientException('connection refused'),
        ),
      );
      await expectLater(
        remote.pull(),
        throwsA(
          isA<RemoteException>().having(
            (e) => e.kind,
            'kind',
            RemoteFailureKind.network,
          ),
        ),
      );
    });

    test('a request that exceeds the timeout is a network failure', () async {
      final remote = storeWith(
        MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        remote.pull(),
        throwsA(
          isA<RemoteException>().having(
            (e) => e.kind,
            'kind',
            RemoteFailureKind.network,
          ),
        ),
      );
    });

    test('malformed responses are server failures, not crashes', () async {
      for (final body in [
        'not json',
        '[]',
        '{"items": 5}',
        '{"items":[{"id":1}]}',
      ]) {
        final remote = storeWith(
          MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          remote.pull(),
          throwsA(
            isA<RemoteException>().having(
              (e) => e.kind,
              'kind',
              RemoteFailureKind.server,
            ),
          ),
          reason: body,
        );
      }
    });

    test('works end to end with the sync engine', () async {
      final server = FakeRemoteNoteStore();
      final local = InMemoryLocalSyncStore()..write(note('a'));
      final engine = SyncEngine(
        local: local,
        remote: storeWith(serverFor(server)),
      );
      final report = await engine.syncOnce();
      expect(report.ok, isTrue);
      expect(server.get('a'), note('a'));
      expect(local.isQueued('a'), isFalse);
    });
  });
}

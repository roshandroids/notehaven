import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:notehaven_sync/notehaven_sync.dart';

/// [RemoteNoteStore] over plain HTTP + JSON; the protocol is documented in
/// `documentation/sync_protocol.md`. No vendor SDK is involved, so any server
/// that speaks the protocol works (a Supabase/PostgREST function, a Firebase
/// HTTP function, your own API).
///
/// Auth: [headers] is called before every request so a token that was
/// refreshed in the meantime is always used. This class never stores or logs
/// credentials.
class RestRemoteNoteStore implements RemoteNoteStore {
  RestRemoteNoteStore({
    required this.baseUrl,
    required this._client,
    this.headers,
    this.timeout = const Duration(seconds: 30),
  });

  /// API root, for example `https://api.example.com/v1`.
  final Uri baseUrl;

  /// Extra headers per request (for example `Authorization`).
  final Future<Map<String, String>> Function()? headers;

  final Duration timeout;
  final http.Client _client;

  Uri _url(List<String> segments, [Map<String, String>? query]) =>
      baseUrl.replace(
        pathSegments: [
          ...baseUrl.pathSegments.where((s) => s.isNotEmpty),
          ...segments,
        ],
        queryParameters: query,
      );

  Future<Map<String, String>> _headers() async => {
    'accept': 'application/json',
    ...?await headers?.call(),
  };

  @override
  Future<PullPage> pull({String? cursor, int limit = 100}) async {
    final response = await _send(
      push: false,
      () async => _client.get(
        _url(['notes', 'changes'], {'limit': '$limit', 'cursor': ?cursor}),
        headers: await _headers(),
      ),
    );
    try {
      final json = _decode(response);
      final items = json['items'];
      if (items is! List) throw const FormatException('"items" must be a list');
      return PullPage(
        items: [
          for (final item in items)
            SyncNote.fromJson((item as Map).cast<String, Object?>()),
        ],
        nextCursor: json['nextCursor'] as String?,
        hasMore: json['hasMore'] == true,
      );
    } on FormatException catch (e) {
      throw RemoteException(
        RemoteFailureKind.server,
        'bad pull response: ${e.message}',
      );
    } on TypeError catch (e) {
      throw RemoteException(RemoteFailureKind.server, 'bad pull response: $e');
    }
  }

  @override
  Future<SyncNote> push(SyncNote note) async {
    final response = await _send(
      push: true,
      () async => _client.put(
        _url(['notes', note.id]),
        headers: {...await _headers(), 'content-type': 'application/json'},
        body: jsonEncode(note.toJson()),
      ),
    );
    try {
      return SyncNote.fromJson(_decode(response));
    } on FormatException catch (e) {
      throw RemoteException(
        RemoteFailureKind.server,
        'bad push response: ${e.message}',
      );
    }
  }

  Map<String, Object?> _decode(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map) throw const FormatException('expected a JSON object');
    return body.cast<String, Object?>();
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required bool push,
  }) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const RemoteException(
        RemoteFailureKind.network,
        'request timed out',
      );
    } on http.ClientException catch (e) {
      throw RemoteException(RemoteFailureKind.network, e.message);
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;
    final detail = 'HTTP $status';
    if (status == 401 || status == 403) {
      throw RemoteException(RemoteFailureKind.auth, detail);
    }
    if (status == 408 || status == 425 || status == 429) {
      throw RemoteException(RemoteFailureKind.network, detail);
    }
    if (push &&
        (status == 400 || status == 409 || status == 413 || status == 422)) {
      throw RemoteException(RemoteFailureKind.rejected, detail);
    }
    throw RemoteException(RemoteFailureKind.server, detail);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notehaven_app/shared/crash/crash_log.dart';
import 'package:notehaven_app/shared/update/update_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('CrashLog', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('keeps newest first, capped, and clears', () async {
      final log = CrashLog(SharedPreferencesAsync());
      for (var i = 0; i < CrashLog.maxEntries + 5; i++) {
        await log.record('error $i', StackTrace.current);
      }
      final entries = await log.entries();
      expect(entries, hasLength(CrashLog.maxEntries));
      expect(entries.first, contains('error ${CrashLog.maxEntries + 4}'));
      await log.clear();
      expect(await log.entries(), isEmpty);
    });
  });

  group('update check', () {
    test('compares versions numerically', () {
      expect(isNewerVersion('0.10.0', '0.9.0'), isTrue);
      expect(isNewerVersion('1.0', '1.0.0+3'), isFalse);
      expect(isNewerVersion('0.1.0', '0.1.1'), isFalse);
    });

    test('reads the latest release; 404 means none', () async {
      final ok = MockClient(
        (_) async => http.Response(
          '{"tag_name":"v0.2.0","html_url":"https://x/r"}',
          200,
        ),
      );
      final info = await fetchLatestRelease(client: ok);
      expect(info?.version, '0.2.0');
      expect(info?.url, 'https://x/r');
      final none = MockClient((_) async => http.Response('', 404));
      expect(await fetchLatestRelease(client: none), isNull);
      final limited = MockClient((_) async => http.Response('', 403));
      expect(fetchLatestRelease(client: limited), throwsException);
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last few unhandled errors, kept on this device only (never uploaded)
/// so a user can read or share them from Settings.
class CrashLog {
  CrashLog([SharedPreferencesAsync? prefs]) : _prefsOverride = prefs;

  static const _key = 'crash_log';
  static const maxEntries = 20;
  static const _maxStackChars = 2000;

  final SharedPreferencesAsync? _prefsOverride;
  late final SharedPreferencesAsync _prefs =
      _prefsOverride ?? SharedPreferencesAsync();

  /// Newest first.
  Future<List<String>> entries() async =>
      await _prefs.getStringList(_key) ?? [];

  /// Never throws: a broken log must not turn one crash into two.
  Future<void> record(Object error, StackTrace? stack) async {
    try {
      var trace = '${stack ?? ''}';
      if (trace.length > _maxStackChars) {
        trace = trace.substring(0, _maxStackChars);
      }
      final entry = '${DateTime.now().toIso8601String()}\n$error\n$trace';
      final all = [entry, ...await entries()].take(maxEntries).toList();
      await _prefs.setStringList(_key, all);
    } on Object {
      // Nothing left to report to.
    }
  }

  Future<void> clear() => _prefs.remove(_key);
}

final crashLogProvider = Provider<CrashLog>((ref) => CrashLog());

/// Records every unhandled error and replaces the red error screen with a
/// friendly one in release builds. Call once from `main` before anything
/// else can throw; not from `App`, so widget tests keep their own handler.
void installCrashHandling(CrashLog log) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    log.record(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.record(error, stack);
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const _FriendlyError();
  }
}

class _FriendlyError extends StatelessWidget {
  const _FriendlyError();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Something went wrong here. Go back and try again.',
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      ),
    ),
  );
}

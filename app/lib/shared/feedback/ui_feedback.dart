import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sound_player.dart';
import 'tones.dart';

/// Named moments the app gives haptic (and optionally audible) feedback for.
/// Feedback is only ever an extra: every event also has a visible result.
enum FeedbackEvent {
  tap,
  select,
  success,
  warning,
  delete,
  undo,
  error,
  strokeStart,
  strokeEnd,
}

/// Which feedback channels the user turned on.
class FeedbackPrefs {
  const FeedbackPrefs({this.haptics = true, this.sounds = false});

  /// Nothing fires; the default until settings are wired in `app/`.
  static const silent = FeedbackPrefs(haptics: false);

  final bool haptics;
  final bool sounds;
}

/// App-wide feedback entry point. Screens depend on this interface so tests
/// can substitute a fake.
abstract interface class UiFeedback {
  /// Fires [event] on every enabled channel. Never throws.
  void play(FeedbackEvent event);
}

/// Real implementation: platform haptics plus code-generated tones.
class DeviceUiFeedback implements UiFeedback {
  DeviceUiFeedback({required this.prefs, SoundPlayer? sound, bool? supported})
    : _sound = sound ?? NoSoundPlayer(),
      _hapticsSupported = supported ?? _platformHasHaptics;

  /// Read on every call, so a settings change applies immediately.
  final FeedbackPrefs Function() prefs;
  final SoundPlayer _sound;
  final bool _hapticsSupported;

  static bool get _platformHasHaptics =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  void play(FeedbackEvent event) {
    final p = prefs();
    if (p.haptics && _hapticsSupported) _haptic(event);
    if (p.sounds && hasTone(event)) _sound.play(event);
  }

  void _haptic(FeedbackEvent event) {
    final call = switch (event) {
      FeedbackEvent.tap ||
      FeedbackEvent.strokeStart => HapticFeedback.lightImpact,
      FeedbackEvent.select ||
      FeedbackEvent.undo => HapticFeedback.selectionClick,
      FeedbackEvent.strokeEnd => HapticFeedback.selectionClick,
      FeedbackEvent.success => HapticFeedback.lightImpact,
      FeedbackEvent.delete => HapticFeedback.mediumImpact,
      FeedbackEvent.warning ||
      FeedbackEvent.error => HapticFeedback.heavyImpact,
    };
    // Haptics are best effort; a missing engine must never break the UI.
    call().catchError((Object _) {});
  }
}

/// Overridden in `app/` so settings drive the service; silent until then.
final feedbackPrefsProvider = Provider<FeedbackPrefs>(
  (ref) => FeedbackPrefs.silent,
);

/// The feedback service; tests override this with a fake.
final feedbackProvider = Provider<UiFeedback>((ref) {
  final sound = AudioPlayersSoundPlayer();
  ref.onDispose(sound.dispose);
  return DeviceUiFeedback(
    prefs: () => ref.read(feedbackPrefsProvider),
    sound: sound,
  );
});

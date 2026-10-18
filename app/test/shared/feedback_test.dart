import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/shared/feedback/sound_player.dart';
import 'package:notehaven_app/shared/feedback/tones.dart';
import 'package:notehaven_app/shared/feedback/ui_feedback.dart';

class _RecordingSound implements SoundPlayer {
  final played = <FeedbackEvent>[];

  @override
  void play(FeedbackEvent event) => played.add(event);

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> haptics;
  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  DeviceUiFeedback make(FeedbackPrefs prefs, _RecordingSound sound) =>
      DeviceUiFeedback(prefs: () => prefs, sound: sound, supported: true);

  test('haptics on, sounds off: vibrates, stays silent', () async {
    final sound = _RecordingSound();
    make(const FeedbackPrefs(), sound).play(FeedbackEvent.delete);
    await Future<void>.delayed(Duration.zero);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    expect(sound.played, isEmpty);
  });

  test('sounds on plays only events that have a tone', () {
    final sound = _RecordingSound();
    final f = make(const FeedbackPrefs(haptics: false, sounds: true), sound);
    f.play(FeedbackEvent.success);
    f.play(FeedbackEvent.tap);
    expect(sound.played, [FeedbackEvent.success]);
    expect(haptics, isEmpty);
  });

  test('everything off is a no-op, and unsupported platforms skip haptics', () {
    final sound = _RecordingSound();
    make(FeedbackPrefs.silent, sound).play(FeedbackEvent.error);
    DeviceUiFeedback(
      prefs: () => const FeedbackPrefs(),
      sound: sound,
      supported: false,
    ).play(FeedbackEvent.error);
    expect(haptics, isEmpty);
    expect(sound.played, isEmpty);
  });

  test('prefs are read per call, so toggles apply immediately', () {
    var prefs = FeedbackPrefs.silent;
    final sound = _RecordingSound();
    final f = DeviceUiFeedback(
      prefs: () => prefs,
      sound: sound,
      supported: false,
    );
    f.play(FeedbackEvent.undo);
    prefs = const FeedbackPrefs(haptics: false, sounds: true);
    f.play(FeedbackEvent.undo);
    expect(sound.played, [FeedbackEvent.undo]);
  });

  test('tones are valid WAV data', () {
    for (final e in [
      FeedbackEvent.success,
      FeedbackEvent.delete,
      FeedbackEvent.undo,
      FeedbackEvent.error,
    ]) {
      final wav = toneWav(e)!;
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(
        ByteData.sublistView(wav).getUint32(4, Endian.little),
        wav.length - 8,
      );
    }
    expect(toneWav(FeedbackEvent.tap), isNull);
  });
}

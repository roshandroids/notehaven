import 'dart:math' as math;
import 'dart:typed_data';

import 'ui_feedback.dart';

/// Short UI tones synthesized in code, so the app ships no audio files (and
/// no third-party audio licences). Each tone is a list of (Hz, milliseconds)
/// notes rendered as a 16-bit mono WAV.
const _notes = <FeedbackEvent, List<(double, int)>>{
  FeedbackEvent.success: [(660, 70), (880, 110)],
  FeedbackEvent.delete: [(440, 70), (294, 120)],
  FeedbackEvent.undo: [(520, 60), (700, 60)],
  FeedbackEvent.error: [(220, 90), (196, 160)],
};

/// Whether [event] has a sound; haptic-only events (tap, strokes) stay silent.
bool hasTone(FeedbackEvent event) => _notes.containsKey(event);

const _sampleRate = 22050;

/// WAV bytes for [event]'s tone, or null when it has none.
Uint8List? toneWav(FeedbackEvent event) {
  final notes = _notes[event];
  if (notes == null) return null;
  final samples = <int>[];
  for (final (hz, ms) in notes) {
    final n = _sampleRate * ms ~/ 1000;
    for (var i = 0; i < n; i++) {
      // Fade in/out over 8 ms so notes do not click.
      final edge = math.min(math.min(i, n - i) / (_sampleRate * 0.008), 1.0);
      final v = math.sin(2 * math.pi * hz * i / _sampleRate) * 0.35 * edge;
      samples.add((v * 32767).round());
    }
  }
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, _sampleRate, Endian.little);
  data.setUint32(28, _sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

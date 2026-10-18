import 'package:audioplayers/audioplayers.dart';

import 'tones.dart';
import 'ui_feedback.dart';

/// Plays the tone for a [FeedbackEvent].
abstract interface class SoundPlayer {
  void play(FeedbackEvent event);
  void dispose();
}

/// Silent player used when no audio backend is wired (tests, previews).
class NoSoundPlayer implements SoundPlayer {
  @override
  void play(FeedbackEvent event) {}

  @override
  void dispose() {}
}

/// `audioplayers` backend. The player is created on first use so the app
/// never touches the audio stack while sounds are off.
///
/// shortcut: plays from in-memory bytes; if a platform rejects `BytesSource`
/// the error is swallowed and that platform stays silent.
class AudioPlayersSoundPlayer implements SoundPlayer {
  AudioPlayer? _player;

  @override
  void play(FeedbackEvent event) {
    final wav = toneWav(event);
    if (wav == null) return;
    final player = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    player
        .play(BytesSource(wav, mimeType: 'audio/wav'))
        .catchError((Object _) {});
  }

  @override
  void dispose() => _player?.dispose();
}

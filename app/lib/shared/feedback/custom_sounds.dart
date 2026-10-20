import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'ui_feedback.dart';

/// Events whose tone the user may replace with their own audio file.
const customizableEvents = [
  FeedbackEvent.success,
  FeedbackEvent.delete,
  FeedbackEvent.undo,
  FeedbackEvent.error,
];

const _maxBytes = 2 * 1024 * 1024;

/// Whether this platform can store custom sounds (not on web).
bool get customSoundsSupported => !kIsWeb;

/// Picked files are copied here, not left in the picker's cache, because the
/// cache can be cleared by the OS (and by Settings > Clear cache).
Future<Directory> _dir() async {
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}/sounds').create(recursive: true);
}

/// The user's file for [event], or null to use the built-in tone.
Future<File?> customSoundFor(FeedbackEvent event) async {
  if (!customSoundsSupported) return null;
  try {
    for (final f in (await _dir()).listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.startsWith('${event.name}.')) return f;
    }
  } on Object {
    // Missing plugin or file system error: fall back to the built-in tone.
  }
  return null;
}

/// Lets the user pick an audio file (max 2 MB) for [event]. Returns the file
/// name, or null when cancelled. Throws [Exception] with a readable message
/// for files that are too large.
Future<String?> pickCustomSound(FeedbackEvent event) async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
  );
  if (picked.isEmpty) return null;
  final file = picked.first;
  final path = file.path;
  if (path == null) return null;
  if (File(path).lengthSync() > _maxBytes) {
    throw Exception('Choose a sound under 2 MB');
  }
  await resetCustomSound(event);
  final ext = path.split('.').last.toLowerCase();
  await File(path).copy('${(await _dir()).path}/${event.name}.$ext');
  return file.name;
}

Future<void> resetCustomSound(FeedbackEvent event) async {
  final f = await customSoundFor(event);
  if (f != null) await f.delete();
}

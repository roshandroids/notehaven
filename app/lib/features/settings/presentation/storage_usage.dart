import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Bytes the app keeps on this device.
class StorageUsage {
  const StorageUsage({required this.notes, required this.cache});

  /// The notes database.
  final int notes;

  /// Temp files and downloaded font files; safe to delete.
  final int cache;
}

int _size(Iterable<FileSystemEntity> files) =>
    files.whereType<File>().fold(0, (sum, f) => sum + f.lengthSync());

bool _isFont(FileSystemEntity f) =>
    f.path.endsWith('.ttf') || f.path.endsWith('.otf');

/// Null where there is no file system access (web) or the plugin is missing.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage?>((
  ref,
) async {
  if (kIsWeb) return null;
  try {
    final docs = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final temp = await getTemporaryDirectory();
    return StorageUsage(
      notes: _size(docs.listSync().where((f) => f.path.contains('notehaven'))),
      cache:
          _size(temp.listSync(recursive: true)) +
          _size(support.listSync().where(_isFont)),
    );
  } on Object {
    return null;
  }
});

/// Deletes temp files and cached fonts. Notes are never touched.
Future<void> clearCache() async {
  final support = await getApplicationSupportDirectory();
  final temp = await getTemporaryDirectory();
  for (final f in temp.listSync()) {
    f.deleteSync(recursive: true);
  }
  for (final f in support.listSync().where(_isFont)) {
    f.deleteSync();
  }
}

/// 1536 -> "1.5 KB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(1)} ${units[i]}';
}

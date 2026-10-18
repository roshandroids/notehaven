import 'package:notehaven_core/notehaven_core.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// One note. Immutable; use [copyWith] to change it.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  /// New note with a fresh UUID; [now] is injectable for tests.
  factory Note.create(String title, String body, {DateTime? now}) {
    final time = now ?? DateTime.now();
    return Note(
      id: _uuid.v4(),
      title: title.trim(),
      body: body,
      createdAt: time,
      updatedAt: time,
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// A note needs a title or a body; returns the failure or null if valid.
  static ValidationFailure? validate(String title, String body) =>
      title.trim().isEmpty && body.trim().isEmpty
      ? const ValidationFailure('Note is empty')
      : null;

  Note copyWith({String? title, String? body, DateTime? updatedAt}) => Note(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

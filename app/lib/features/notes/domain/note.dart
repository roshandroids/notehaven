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
    this.content,
  });

  /// New note with a fresh UUID; [now] is injectable for tests.
  factory Note.create(
    String title,
    String body, {
    String? content,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    return Note(
      id: _uuid.v4(),
      title: title.trim(),
      body: body,
      createdAt: time,
      updatedAt: time,
      content: content,
    );
  }

  final String id;
  final String title;

  /// Plain-text mirror of the note, used for search, previews and clients
  /// without a rich editor. Derived from [content] on every save.
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Rich content (the editor's document JSON), opaque to the domain. Null for
  /// plain-text notes.
  final String? content;

  /// A note needs a title, a body or [content] (a drawing-only note has
  /// content but no text); returns the failure or null if valid. Callers pass
  /// null content for an empty document.
  static ValidationFailure? validate(
    String title,
    String body, {
    String? content,
  }) => title.trim().isEmpty && body.trim().isEmpty && content == null
      ? const ValidationFailure('Note is empty')
      : null;

  /// Copy with changes. `content` replaces the current value; pass
  /// `clearContent: true` to remove it.
  Note copyWith({
    String? title,
    String? body,
    String? content,
    bool clearContent = false,
    DateTime? updatedAt,
  }) => Note(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    content: clearContent ? null : (content ?? this.content),
  );
}

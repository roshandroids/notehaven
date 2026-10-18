/// A note as it travels between device and server (tombstones included).
///
/// [updatedAt] is the last-write-wins clock (millisecond precision, UTC).
/// Equality ignores [createdAt] and the exact [deletedAt] instant because
/// local storage may round them; only whether the note is deleted matters.
class SyncNote {
  const SyncNote({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.content,
  });

  /// Parses the wire format; throws [FormatException] on a malformed payload.
  factory SyncNote.fromJson(Map<String, Object?> json) {
    String text(String key) {
      final v = json[key];
      if (v is String) return v;
      throw FormatException('"$key" must be a string', json);
    }

    DateTime time(String key) => DateTime.parse(text(key)).toUtc();

    final deleted = json['deletedAt'];
    final content = json['content'];
    if (content != null && content is! String) {
      throw FormatException('"content" must be a string', json);
    }
    return SyncNote(
      id: text('id'),
      title: text('title'),
      body: text('body'),
      createdAt: time('createdAt'),
      updatedAt: time('updatedAt'),
      deletedAt: deleted == null ? null : time('deletedAt'),
      content: content as String?,
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  /// The conflict clock: higher wins; must increase on every change.
  final DateTime updatedAt;

  /// Non-null for a tombstone (the note was deleted).
  final DateTime? deletedAt;

  /// Rich content (for example an editor's JSON). Opaque to sync: servers must
  /// store it and return it unchanged. Absent for plain-text notes and for
  /// clients that predate the field.
  final String? content;

  bool get isDeleted => deletedAt != null;

  /// Wire format (ISO-8601 UTC timestamps).
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
    'content': ?content,
  };

  @override
  bool operator ==(Object other) =>
      other is SyncNote &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.content == content &&
      other.updatedAt.millisecondsSinceEpoch ==
          updatedAt.millisecondsSinceEpoch &&
      other.isDeleted == isDeleted;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    body,
    content,
    updatedAt.millisecondsSinceEpoch,
    isDeleted,
  );

  @override
  String toString() =>
      'SyncNote($id, "$title", ${updatedAt.toIso8601String()}${isDeleted ? ', deleted' : ''})';
}

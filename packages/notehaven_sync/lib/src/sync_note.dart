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
    return SyncNote(
      id: text('id'),
      title: text('title'),
      body: text('body'),
      createdAt: time('createdAt'),
      updatedAt: time('updatedAt'),
      deletedAt: deleted == null ? null : time('deletedAt'),
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

  bool get isDeleted => deletedAt != null;

  /// Wire format (ISO-8601 UTC timestamps).
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is SyncNote &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.updatedAt.millisecondsSinceEpoch ==
          updatedAt.millisecondsSinceEpoch &&
      other.isDeleted == isDeleted;

  @override
  int get hashCode =>
      Object.hash(id, title, body, updatedAt.millisecondsSinceEpoch, isDeleted);

  @override
  String toString() =>
      'SyncNote($id, "$title", ${updatedAt.toIso8601String()}${isDeleted ? ', deleted' : ''})';
}

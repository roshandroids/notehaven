import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

import '../domain/note.dart';

/// The two stored forms of an edited document: the plain-text mirror and the
/// rich content JSON.
typedef SerializedDocument = ({String body, String? content});

/// Opens [note] in the editor.
///
/// Notes without rich content (older notes, synced from a plain client) start
/// from their plain [Note.body]. Content that fails to parse also falls back to
/// the body, so a damaged document never makes a note unopenable.
Document documentFor(Note? note) {
  final content = note?.content;
  if (content != null) {
    try {
      return Document.fromJson(jsonDecode(content) as List);
    } on Object {
      // fall through to the plain-text body
    }
  }
  final body = note?.body ?? '';
  return body.isEmpty ? Document() : (Document()..insert(0, body));
}

/// Plain text of [document] without embed placeholders or the trailing newline.
String plainTextOf(Document document) => document
    .toPlainText()
    .replaceAll(Embed.kObjectReplacementCharacter, '')
    .trim();

/// Serializes [document] for saving.
///
/// `body` is the plain-text mirror used for search and previews. `content` is
/// null for an empty document (no text and no embeds) so an empty note is
/// rejected by validation instead of being saved.
SerializedDocument serializeDocument(Document document) {
  final body = plainTextOf(document);
  final hasEmbed = document.toDelta().toList().any((op) => op.data is Map);
  final empty = body.isEmpty && !hasEmbed;
  return (
    body: body,
    content: empty ? null : jsonEncode(document.toDelta().toJson()),
  );
}

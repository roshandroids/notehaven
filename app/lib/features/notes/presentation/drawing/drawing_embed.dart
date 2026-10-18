import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../shared/layout/layout.dart';
import '../../domain/drawing.dart';
import 'drawing_editor_screen.dart';
import 'drawing_painter.dart';

/// Embed type stored in the note's Quill document for a drawing.
const drawingEmbedType = 'drawing';

/// Builds the block embed for [drawing]. A plain `BlockEmbed` is stored as
/// `{"insert":{"drawing":"<json>"}}`; `BlockEmbed.custom` would wrap the data
/// in extra JSON string escaping and inflate the stored size.
BlockEmbed drawingEmbed(Drawing drawing) =>
    BlockEmbed(drawingEmbedType, drawing.toJsonString());

/// Renders a drawing inside the editor as a tappable thumbnail.
///
/// Register this on every `QuillEditor` that can show the note: a document
/// that contains an unregistered embed type fails to render.
class DrawingEmbedBuilder extends EmbedBuilder {
  const DrawingEmbedBuilder();

  @override
  String get key => drawingEmbedType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final drawing = Drawing.tryParse(embedContext.node.value.data as String);
    if (drawing == null) {
      return Semantics(
        label: 'Drawing that cannot be shown (unsupported or damaged format)',
        child: const Card(
          child: ListTile(
            leading: Icon(Icons.broken_image_outlined),
            title: Text('Drawing can\'t be shown'),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        button: true,
        label: embedContext.readOnly
            ? 'Drawing'
            : 'Drawing. Double tap to edit.',
        excludeSemantics: true,
        onTap: embedContext.readOnly
            ? null
            : () => _edit(context, embedContext, drawing),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: embedContext.readOnly
                  ? null
                  : () => _edit(context, embedContext, drawing),
              // Cross-fades when the drawing is edited and re-inserted.
              child: AnimatedSwitcher(
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                child: DrawingThumbnail(
                  key: ValueKey(embedContext.node.value.data.hashCode),
                  drawing: drawing,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    EmbedContext embedContext,
    Drawing drawing,
  ) async {
    final result = await openDrawingEditor(context, drawing);
    if (result == null) return;
    final node = embedContext.node;
    if (node.parent == null) return; // removed while the editor was open
    // The offset is read after the await: the document may have changed.
    final offset = node.documentOffset;
    embedContext.controller.replaceText(
      offset,
      1,
      result.isEmpty ? '' : drawingEmbed(result),
      null,
    );
  }
}

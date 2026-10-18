import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/feedback/ui_feedback.dart';
import '../domain/note.dart';
import 'drawing/drawing_editor_screen.dart';
import 'drawing/drawing_embed.dart';
import 'note_actions.dart';
import 'note_document.dart';
import 'note_providers.dart';

/// Id used in the route for a note that does not exist yet.
const newNoteId = 'new';

/// Create or edit one note. Route: `/notes/:id` (`new` creates).
class NoteEditorScreen extends ConsumerWidget {
  const NoteEditorScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == newNoteId) return const _NoteForm(note: null);
    return ref
        .watch(noteProvider(id))
        .when(
          data: (note) => note == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: const Center(child: Text('Note not found')),
                )
              : _NoteForm(note: note),
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Could not load note: $e')),
          ),
        );
  }
}

class _NoteForm extends ConsumerStatefulWidget {
  const _NoteForm({required this.note});

  final Note? note;

  @override
  ConsumerState<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends ConsumerState<_NoteForm> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _quill = QuillController(
    document: documentFor(widget.note),
    selection: const TextSelection.collapsed(offset: 0),
  );
  final _editorFocus = FocusNode();
  final _editorScroll = ScrollController();

  @override
  void dispose() {
    _title.dispose();
    _quill.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  /// Leaves the editor: back in narrow layouts, to the empty pane in split view.
  void _close() => context.canPop() ? context.pop() : context.go('/');

  /// Opens the sketch pad and inserts the result at the cursor.
  Future<void> _insertDrawing() async {
    final drawing = await openDrawingEditor(context);
    if (!mounted || drawing == null || drawing.isEmpty) return;
    // Cursor position is read after the await, not before.
    final index = _quill.selection.baseOffset.clamp(
      0,
      _quill.document.length - 1,
    );
    _quill.replaceText(index, 0, drawingEmbed(drawing), null);
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    final feedback = ref.read(feedbackProvider);
    final messenger = ScaffoldMessenger.of(context);
    final doc = serializeDocument(_quill.document);
    final failure = await ref
        .read(noteActionsProvider)
        .save(
          existing: widget.note,
          title: _title.text,
          body: doc.body,
          content: doc.content,
        );
    if (!mounted) return;
    if (failure == null) {
      feedback.play(FeedbackEvent.success);
      _close();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline),
                SizedBox(width: 12),
                Text('Note saved'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
    } else {
      feedback.play(FeedbackEvent.error);
      _showMessage(failure.message);
    }
  }

  Future<void> _delete() async {
    final note = widget.note!;
    final actions = ref.read(noteActionsProvider);
    final feedback = ref.read(feedbackProvider)..play(FeedbackEvent.delete);
    final messenger = ScaffoldMessenger.of(context);
    final failure = await actions.delete(note.id);
    if (!mounted) return;
    if (failure != null) {
      feedback.play(FeedbackEvent.error);
      _showMessage(failure.message);
      return;
    }
    _close();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            feedback.play(FeedbackEvent.undo);
            actions.restore(note);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (widget.note != null)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            IconButton(
              tooltip: 'Insert drawing',
              icon: const Icon(Icons.draw_outlined),
              onPressed: _insertDrawing,
            ),
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    key: const Key('note-title'),
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    style: theme.textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                    ),
                  ),
                  QuillSimpleToolbar(
                    controller: _quill,
                    config: const QuillSimpleToolbarConfig(
                      // One scrollable row, so it never wraps on a narrow pane.
                      multiRowsDisplay: false,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showInlineCode: false,
                      showClearFormat: false,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: QuillEditor(
                      key: const Key('note-body'),
                      controller: _quill,
                      focusNode: _editorFocus,
                      scrollController: _editorScroll,
                      config: const QuillEditorConfig(
                        placeholder: 'Write something…',
                        padding: EdgeInsets.symmetric(vertical: 12),
                        embedBuilders: [DrawingEmbedBuilder()],
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _quill,
                    builder: (context, _) {
                      final text = plainTextOf(_quill.document);
                      final words = text.isEmpty
                          ? 0
                          : text.split(RegExp(r'\s+')).length;
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$words words · ${text.length} characters',
                          style: theme.textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
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

  /// Phone only: the formatting toolbar expands from the FAB.
  bool _formatOpen = false;

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
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
                const SizedBox(width: 12),
                const Text('Note saved'),
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
        persist: false,
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

  /// Toolbar card that grows out of the bottom-right FAB.
  Widget _formatFab(Widget toolbar) {
    final scheme = Theme.of(context).colorScheme;
    final motion = MediaQuery.disableAnimationsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: motion ? Duration.zero : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (w, a) => ScaleTransition(
            alignment: Alignment.bottomRight,
            scale: a,
            child: FadeTransition(opacity: a, child: w),
          ),
          child: _formatOpen
              ? Padding(
                  key: const ValueKey('format-bar'),
                  padding: const EdgeInsets.only(bottom: 12, left: 16),
                  child: Card(
                    elevation: 3,
                    color: scheme.surfaceContainerHigh,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width - 32,
                      child: toolbar,
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('format-closed')),
        ),
        FloatingActionButton(
          heroTag: 'format-fab',
          tooltip: _formatOpen ? 'Hide formatting' : 'Formatting',
          onPressed: () => setState(() => _formatOpen = !_formatOpen),
          child: Icon(
            _formatOpen ? Symbols.close_rounded : Symbols.text_format_rounded,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final toolbar = Material(
      color: wide ? theme.colorScheme.surfaceContainerHigh : Colors.transparent,
      borderRadius: BorderRadius.circular(wide ? 12 : 0),
      child: QuillSimpleToolbar(
        controller: _quill,
        config: QuillSimpleToolbarConfig(
          // Wide: Word-style ribbon wrapping onto rows. Phone: one slim row.
          multiRowsDisplay: wide,
          showSubscript: wide,
          showSuperscript: wide,
          showFontFamily: wide,
          showFontSize: wide,
          showInlineCode: false,
          showClearFormat: true,
          showAlignmentButtons: true,
          showLink: true,
          showSearchButton: wide,
          // Phone: bigger tap targets in the bottom row.
          toolbarSize: wide ? null : 52,
          buttonOptions: QuillSimpleToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(iconSize: wide ? null : 26),
            bold: _toggle(Symbols.format_bold_rounded),
            italic: _toggle(Symbols.format_italic_rounded),
            underLine: _toggle(Symbols.format_underlined_rounded),
            strikeThrough: _toggle(Symbols.format_strikethrough_rounded),
            subscript: _toggle(Symbols.subscript_rounded),
            superscript: _toggle(Symbols.superscript_rounded),
            listBullets: _toggle(Symbols.format_list_bulleted_rounded),
            listNumbers: _toggle(Symbols.format_list_numbered_rounded),
            quote: _toggle(Symbols.format_quote_rounded),
          ),
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'New note' : 'Edit note'),
          actions: [
            if (widget.note != null) ...[
              IconButton.outlined(
                tooltip: 'Delete',
                icon: const Icon(Symbols.delete_rounded),
                onPressed: _delete,
              ),
              const SizedBox(width: 8),
            ],
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Insert drawing',
              icon: const Icon(Symbols.draw_rounded),
              onPressed: _insertDrawing,
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Save',
              icon: const Icon(Symbols.check_rounded),
              onPressed: _save,
            ),
            const SizedBox(width: 12),
          ],
        ),
        floatingActionButton: wide ? null : _formatFab(toolbar),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
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
                  if (wide) ...[toolbar, const Divider(height: 1)],
                  Expanded(
                    child: QuillEditor(
                      key: const Key('note-body'),
                      controller: _quill,
                      focusNode: _editorFocus,
                      scrollController: _editorScroll,
                      config: QuillEditorConfig(
                        placeholder: 'Write something…',
                        // Room for the formatting FAB on phones.
                        padding: EdgeInsets.only(
                          top: 12,
                          bottom: wide ? 12 : 88,
                        ),
                        embedBuilders: const [DrawingEmbedBuilder()],
                      ),
                    ),
                  ),
                  if (!wide) ...[
                    const Divider(height: 1),
                    SafeArea(top: false, child: toolbar),
                  ],
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

QuillToolbarToggleStyleButtonOptions _toggle(IconData icon) =>
    QuillToolbarToggleStyleButtonOptions(iconData: icon);

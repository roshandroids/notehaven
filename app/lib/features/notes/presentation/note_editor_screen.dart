import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/note.dart';
import 'note_actions.dart';
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
  late final _body = TextEditingController(text: widget.note?.body);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Leaves the editor: back in narrow layouts, to the empty pane in split view.
  void _close() => context.canPop() ? context.pop() : context.go('/');

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    final failure = await ref
        .read(noteActionsProvider)
        .save(existing: widget.note, title: _title.text, body: _body.text);
    if (!mounted) return;
    if (failure == null) {
      HapticFeedback.lightImpact();
      _close();
    } else {
      _showMessage(failure.message);
    }
  }

  Future<void> _delete() async {
    final note = widget.note!;
    final actions = ref.read(noteActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final failure = await actions.delete(note.id);
    if (!mounted) return;
    if (failure != null) {
      _showMessage(failure.message);
      return;
    }
    _close();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => actions.restore(note),
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
          title: Text(widget.note == null ? 'New note' : 'Edit note'),
          actions: [
            if (widget.note != null)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
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
                  const Divider(),
                  Expanded(
                    child: TextField(
                      key: const Key('note-body'),
                      controller: _body,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Write something…',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _body,
                    builder: (context, value, _) {
                      final text = value.text.trim();
                      final words = text.isEmpty
                          ? 0
                          : text.split(RegExp(r'\s+')).length;
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$words words · ${value.text.length} characters',
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

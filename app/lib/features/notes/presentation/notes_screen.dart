import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/feedback/ui_feedback.dart';
import '../../../shared/layout/layout.dart';
import '../../../shared/widgets/search_input.dart';
import '../domain/note.dart';
import 'note_actions.dart';
import 'note_providers.dart';
import 'sync_status_button.dart';

/// Note list: masonry grid, debounced search, swipe actions, Ctrl/Cmd+N.
class NotesScreen extends ConsumerWidget {
  /// [selectedId] highlights the open note when shown as the split-view pane.
  const NotesScreen({this.selectedId, super.key});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final searching = ref.watch(
      searchQueryProvider.select((q) => q.trim().isNotEmpty),
    );
    final split = isSplitView(context);
    void openSettings() => context.push('/settings');
    void newNote() =>
        split ? context.go('/notes/new') : context.push('/notes/new');

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): newNote,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): newNote,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            openSettings,
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            openSettings,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Notehaven'),
            actions: [
              const SyncStatusButton(),
              IconButton(
                tooltip: 'Appearance',
                icon: const Icon(Icons.palette_outlined),
                onPressed: openSettings,
              ),
            ],
          ),
          floatingActionButton: _maybeAnimate(
            context,
            FloatingActionButton.extended(
              onPressed: newNote,
              icon: const Icon(Icons.add),
              label: const Text('New note'),
            ),
            (w) => w.animate().scale(
              duration: 300.ms,
              curve: Curves.easeOutBack,
              begin: const Offset(0.6, 0.6),
            ),
          ),
          body: Column(
            children: [
              const _SearchField(),
              Expanded(
                child: notes.when(
                  data: (items) => items.isEmpty
                      ? _EmptyState(searching: searching)
                      : _NoteGrid(items: items, selectedId: selectedId),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Could not load notes: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Applies [animation] unless the OS asks to reduce motion.
Widget _maybeAnimate(
  BuildContext context,
  Widget child,
  Widget Function(Widget) animation,
) => reduceMotion(context) ? child : animation(child);

/// Search box that waits 250 ms after the last keystroke before querying, so
/// fast typing does not re-run the database query on every character.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => ref.read(searchQueryProvider.notifier).set(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SearchInput(
        key: const Key('search'),
        hintText: 'Search notes',
        onChanged: _onChanged,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: _maybeAnimate(
        context,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _maybeAnimate(
              context,
              Icon(
                searching ? Icons.search_off : Icons.edit_note,
                size: 72,
                color: theme.colorScheme.outline,
              ),
              (w) => w.animate().scale(
                delay: 150.ms,
                duration: 400.ms,
                curve: Curves.elasticOut,
                begin: const Offset(0.5, 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              searching ? 'No matching notes' : 'No notes yet',
              style: theme.textTheme.titleMedium,
            ),
            if (!searching) const Text('Tap "New note" to write one.'),
          ],
        ),
        (w) => w.animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
      ),
    );
  }
}

class _NoteGrid extends StatelessWidget {
  const _NoteGrid({required this.items, required this.selectedId});

  final List<Note> items;
  final String? selectedId;

  /// Only the first screenful animates in; later items would animate while
  /// scrolling, which costs frames for no benefit.
  static const _animatedCount = 12;

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
      ),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final note = items[i];
        final card = RepaintBoundary(
          key: ValueKey(note.id),
          child: _NoteCard(note: note, selected: note.id == selectedId),
        );
        return i < _animatedCount && !reduceMotion(context)
            ? card
                  .animate(delay: (30 * i).ms)
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOut)
            : card;
      },
    );
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note, required this.selected});

  final Note note;
  final bool selected;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final feedback = ref.read(feedbackProvider)..play(FeedbackEvent.delete);
    final actions = ref.read(noteActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final failure = await actions.delete(note.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(failure?.message ?? 'Note deleted'),
          action: failure == null
              ? SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    feedback.play(FeedbackEvent.undo);
                    actions.restore(note);
                  },
                )
              : null,
        ),
      );
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final feedback = ref.read(feedbackProvider);
    final failure = await ref.read(noteActionsProvider).duplicate(note);
    feedback.play(
      failure == null ? FeedbackEvent.success : FeedbackEvent.error,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(failure?.message ?? 'Note copied')),
      );
  }

  /// Long-press / right-click menu: the same actions as the swipe pane, for
  /// mouse and keyboard users who cannot swipe.
  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    ref.read(feedbackProvider).play(FeedbackEvent.tap);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy note'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete note'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'copy') {
      await _duplicate(context, ref);
    } else if (choice == 'delete') {
      await _delete(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = note.title.isEmpty ? 'Untitled' : note.title;
    final split = isSplitView(context);
    void open() => split
        ? context.go('/notes/${note.id}')
        : context.push('/notes/${note.id}');
    final edited = DateFormat.yMMMd().add_jm().format(note.updatedAt);
    return Semantics(
      // One focus stop per note; swipe actions are exposed as custom actions
      // so screen-reader users can copy or delete without a swipe gesture.
      label: [
        title,
        if (note.body.isNotEmpty) note.body,
        'Edited $edited',
      ].join('. '),
      button: true,
      selected: selected,
      onTap: open,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Copy note'): () =>
            _duplicate(context, ref),
        const CustomSemanticsAction(label: 'Delete note'): () =>
            _delete(context, ref),
      },
      excludeSemantics: true,
      child: Slidable(
        key: ValueKey(note.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.5,
          children: [
            SlidableAction(
              onPressed: (_) => _duplicate(context, ref),
              icon: Icons.copy_outlined,
              label: 'Copy',
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
            ),
            SlidableAction(
              onPressed: (_) => _delete(context, ref),
              icon: Icons.delete_outline,
              label: 'Delete',
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: selected ? scheme.secondaryContainer : null,
          child: InkWell(
            onTap: open,
            onLongPress: () => _showMenu(context, ref),
            onSecondaryTap: () => _showMenu(context, ref),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (note.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note.body,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    edited,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
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

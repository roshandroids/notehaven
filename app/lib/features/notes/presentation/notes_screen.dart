import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/feedback/ui_feedback.dart';
import '../../../app/theme/tokens.dart';
import '../../../shared/layout/layout.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../shared/widgets/search_input.dart';
import '../domain/note.dart';
import 'note_actions.dart';
import 'note_providers.dart';
import 'sync_status_button.dart';
import '../../../l10n/l10n.dart';

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
    final grid = ref.watch(gridViewProvider);
    final split = isSplitView(context);
    void openSettings() => context.push('/settings');
    void newNote() =>
        split ? context.go('/notes/new') : context.push('/notes/new');

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): newNote,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): newNote,
        // Browsers reserve Cmd/Ctrl+N for a new window; Alt+N works on web too.
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true): newNote,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            openSettings,
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            openSettings,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          floatingActionButton: _maybeAnimate(
            context,
            FloatingActionButton.extended(
              onPressed: newNote,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.newNote),
            ),
            (w) => w.animate().scale(
              duration: 300.ms,
              curve: Curves.easeOutBack,
              begin: const Offset(0.6, 0.6),
            ),
          ),
          body: CustomScrollView(
            slivers: [
              // Floats in on any upward scroll and snaps shut/open.
              SliverAppBar(
                floating: true,
                snap: true,
                toolbarHeight: 72,
                titleSpacing: 16,
                title: const _SearchField(),
                actions: [
                  const SyncStatusButton(),
                  IconButton.filledTonal(
                    tooltip: context.l10n.settingsTooltip,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: openSettings,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              ...notes.when(
                data: (items) => items.isEmpty
                    ? [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(searching: searching),
                        ),
                      ]
                    : [
                        _NoteGrid(
                          items: items,
                          selectedId: selectedId,
                          grid: grid,
                        ),
                      ],
                loading: () => const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Illustration(IllustrationKind.loading),
                    ),
                  ),
                ],
                error: (e, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: IllustratedMessage(
                      kind: IllustrationKind.error,
                      title: context.l10n.couldNotLoadNotes,
                      subtitle: '$e',
                    ),
                  ),
                ],
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
    return SearchInput(
      key: const Key('search'),
      hintText: context.l10n.searchNotes,
      onChanged: _onChanged,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) => IllustratedMessage(
    kind: searching ? IllustrationKind.search : IllustrationKind.onboarding,
    title: searching ? context.l10n.noMatchingNotes : context.l10n.welcome,
    subtitle: searching ? null : context.l10n.notesAppearHere,
  );
}

class _NoteGrid extends StatelessWidget {
  const _NoteGrid({
    required this.items,
    required this.selectedId,
    required this.grid,
  });

  final bool grid;

  final List<Note> items;
  final String? selectedId;

  /// Only the first screenful animates in; later items would animate while
  /// scrolling, which costs frames for no benefit.
  static const _animatedCount = 12;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      sliver: SliverMasonryGrid(
        gridDelegate: grid
            ? const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
              )
            : const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
              ),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        delegate: SliverChildBuilderDelegate(childCount: items.length, (_, i) {
          final note = items[i];
          final card = RepaintBoundary(
            key: ValueKey(note.id),
            child: _NoteCard(
              note: note,
              selected: note.id == selectedId,
              grid: grid,
            ),
          );
          return i < _animatedCount && !reduceMotion(context)
              ? card
                    .animate(delay: (30 * i).ms)
                    .fadeIn(duration: 250.ms)
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOut)
              : card;
        }),
      ),
    );
  }
}

class _NoteCard extends ConsumerStatefulWidget {
  const _NoteCard({
    required this.note,
    required this.selected,
    required this.grid,
  });

  final Note note;
  final bool selected;

  /// Grid cards are too narrow for swipe actions; they use the long-press menu.
  final bool grid;

  @override
  ConsumerState<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<_NoteCard> {
  Note get note => widget.note;
  bool get selected => widget.selected;
  bool get grid => widget.grid;

  /// True while the card plays its exit animation before the delete lands.
  bool _leaving = false;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final feedback = ref.read(feedbackProvider)..play(FeedbackEvent.delete);
    final actions = ref.read(noteActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (!reduceMotion(context)) {
      setState(() => _leaving = true);
      await Future<void>.delayed(AppMotion.medium);
    }
    final failure = await actions.delete(note.id);
    if (failure != null && mounted) setState(() => _leaving = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(failure?.message ?? l10n.noteDeleted),
          persist: false,
          action: failure == null
              ? SnackBarAction(
                  label: l10n.undo,
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
    final l10n = context.l10n;
    final failure = await ref
        .read(noteActionsProvider)
        .duplicate(note, l10n.copyTitle(_displayTitle(l10n)));
    feedback.play(
      failure == null ? FeedbackEvent.success : FeedbackEvent.error,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(failure?.message ?? l10n.noteCopied)),
      );
  }

  String _displayTitle(AppLocalizations l10n) =>
      note.title.isEmpty ? l10n.untitled : note.title;

  String _shareText(AppLocalizations l10n) {
    final title = _displayTitle(l10n);
    return note.body.isEmpty ? title : '$title\n\n${note.body}';
  }

  /// Long-press / right-click popup anchored at [position].
  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    VoidCallback open,
  ) async {
    ref.read(feedbackProvider).play(FeedbackEvent.tap);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final danger = Theme.of(context).colorScheme.error;
    final l10n = context.l10n;
    PopupMenuItem<String> item(
      String v,
      IconData icon,
      String label, {
      Color? c,
    }) => PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 12),
          Text(label, style: c == null ? null : TextStyle(color: c)),
        ],
      ),
    );
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        item('open', Icons.edit_outlined, l10n.open),
        item('copy', Icons.copy_outlined, l10n.copyNote),
        item('share', Icons.ios_share, l10n.share),
        item('export', Icons.download_outlined, l10n.exportAsText),
        const PopupMenuDivider(),
        item('delete', Icons.delete_outline, l10n.deleteNote, c: danger),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'open':
        open();
      case 'copy':
        await _duplicate(context, ref);
      case 'share':
        await SharePlus.instance.share(
          ShareParams(text: _shareText(l10n), title: note.title),
        );
      case 'export':
        final name = (note.title.isEmpty ? 'note' : note.title).replaceAll(
          RegExp(r'[^\w\- ]'),
          '_',
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                Uint8List.fromList(utf8.encode(_shareText(l10n))),
                mimeType: 'text/plain',
                name: '$name.txt',
              ),
            ],
            fileNameOverrides: ['$name.txt'],
          ),
        );
      case 'delete':
        await _delete(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final title = _displayTitle(l10n);
    final split = isSplitView(context);
    void open() => split
        ? context.go('/notes/${note.id}')
        : context.push('/notes/${note.id}');
    final edited = DateFormat.yMMMd(
      l10n.localeName,
    ).add_jm().format(note.updatedAt);
    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: double.infinity,
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
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      // One focus stop per note; swipe actions are exposed as custom actions
      // so screen-reader users can copy or delete without a swipe gesture.
      label: [
        title,
        if (note.body.isNotEmpty) note.body,
        l10n.edited(edited),
      ].join('. '),
      button: true,
      selected: selected,
      onTap: open,
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.copyNote): () =>
            _duplicate(context, ref),
        CustomSemanticsAction(label: l10n.deleteNote): () =>
            _delete(context, ref),
      },
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _leaving ? 0.85 : 1,
        duration: AppMotion.medium,
        curve: Curves.easeIn,
        child: AnimatedOpacity(
          opacity: _leaving ? 0 : 1,
          duration: AppMotion.medium,
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onLongPressStart: (d) =>
                _showMenu(context, ref, d.globalPosition, open),
            onSecondaryTapDown: (d) =>
                _showMenu(context, ref, d.globalPosition, open),
            child: grid
                ? card
                : Slidable(
                    key: ValueKey(note.id),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      extentRatio: 0.5,
                      children: [
                        SlidableAction(
                          onPressed: (_) => _duplicate(context, ref),
                          icon: Icons.copy_outlined,
                          label: l10n.copy,
                          backgroundColor: scheme.secondaryContainer,
                          foregroundColor: scheme.onSecondaryContainer,
                        ),
                        SlidableAction(
                          onPressed: (_) => _delete(context, ref),
                          icon: Icons.delete_outline,
                          label: l10n.delete,
                          backgroundColor: scheme.errorContainer,
                          foregroundColor: scheme.onErrorContainer,
                        ),
                      ],
                    ),
                    child: card,
                  ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/feedback/ui_feedback.dart';
import '../../../shared/widgets/search_input.dart';
import 'settings_providers.dart';
import '../../../l10n/l10n.dart';

/// Popular families shown with a live preview. Entries missing from the
/// installed google_fonts version are dropped at runtime.
const _curated = [
  'Inter',
  'Roboto',
  'Open Sans',
  'Lato',
  'Montserrat',
  'Poppins',
  'Nunito',
  'Raleway',
  'DM Sans',
  'Manrope',
  'Work Sans',
  'Source Sans 3',
  'Rubik',
  'Quicksand',
  'Lora',
  'Merriweather',
  'Playfair Display',
  'Libre Baskerville',
  'Crimson Text',
  'Caveat',
  'Pacifico',
  'Space Grotesk',
  'IBM Plex Sans',
  'JetBrains Mono',
];

/// Pick a Google Font: curated list with previews, or search all families.
///
/// Performance: only visible rows are built, and only the curated rows render
/// in their own font (each preview downloads that font once, then caches it).
/// Search results show the family name in the default font.
class FontPickerScreen extends ConsumerStatefulWidget {
  const FontPickerScreen({super.key});

  @override
  ConsumerState<FontPickerScreen> createState() => _FontPickerScreenState();
}

class _FontPickerScreenState extends ConsumerState<FontPickerScreen> {
  static final List<String> _all = GoogleFonts.asMap().keys.toList()..sort();
  static final List<String> _curatedAvailable = _curated
      .where(GoogleFonts.asMap().containsKey)
      .toList(growable: false);

  String _query = '';
  final _scroll = ScrollController();
  final _searchFocus = FocusNode();

  /// True once the search field has scrolled out of view.
  final _searchHidden = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _searchHidden.value = _scroll.offset > 72);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchFocus.dispose();
    _searchHidden.dispose();
    super.dispose();
  }

  Future<void> _jumpToSearch() async {
    await _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _searchFocus.requestFocus();
  }

  List<String> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _curatedAvailable;
    return _all.where((f) => f.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(settingsProvider.select((s) => s.fontFamily));
    final controller = ref.read(settingsProvider.notifier);
    final results = _results;
    final preview = _query.trim().isEmpty;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Text(context.l10n.font),
                actions: [
                  ValueListenableBuilder(
                    valueListenable: _searchHidden,
                    builder: (context, hidden, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: hidden
                          ? Padding(
                              key: const ValueKey('search-action'),
                              padding: const EdgeInsets.only(right: 12),
                              child: IconButton.filledTonal(
                                tooltip: context.l10n.searchFonts,
                                icon: const Icon(Icons.search),
                                onPressed: _jumpToSearch,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SearchInput(
                    focusNode: _searchFocus,
                    hintText: context.l10n.searchGoogleFonts(_all.length),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              SliverList.separated(
                separatorBuilder: (_, _) => const Divider(),
                itemCount: results.length + (preview ? 1 : 0),
                itemBuilder: (context, i) {
                  if (preview && i == 0) {
                    return ListTile(
                      title: Text(context.l10n.systemDefault),
                      trailing: selected == null
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () {
                        ref.read(feedbackProvider).play(FeedbackEvent.select);
                        controller.setFont(null);
                      },
                    );
                  }
                  final family = results[i - (preview ? 1 : 0)];
                  return ListTile(
                    key: ValueKey(family),
                    title: Text(family),
                    subtitle: preview
                        ? Text(
                            context.l10n.fontPreview,
                            style: GoogleFonts.getFont(family),
                          )
                        : null,
                    trailing: selected == family
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: () {
                      ref.read(feedbackProvider).play(FeedbackEvent.select);
                      controller.setFont(family);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

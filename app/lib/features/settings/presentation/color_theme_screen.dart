import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/feedback/ui_feedback.dart';
import 'settings_providers.dart';
import '../../../l10n/l10n.dart';

/// Pick a color theme: every FlexColorScheme preset except `custom`, with a
/// swatch preview in the current brightness.
class ColorThemeScreen extends ConsumerWidget {
  const ColorThemeScreen({super.key});

  static final _schemes = FlexScheme.values
      .where((s) => s != FlexScheme.custom)
      .toList(growable: false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final feedback = ref.read(feedbackProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(pinned: true, title: Text(context.l10n.colorTheme)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisExtent: 92,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _schemes.length,
              itemBuilder: (_, i) {
                final scheme = _schemes[i];
                return RepaintBoundary(
                  child: _SchemeTile(
                    key: Key('scheme-${scheme.name}'),
                    scheme: scheme,
                    brightness: brightness,
                    selected: settings.schemeName == scheme.name,
                    onTap: () {
                      feedback.play(FeedbackEvent.select);
                      controller.setScheme(scheme.name);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemeTile extends StatelessWidget {
  const _SchemeTile({
    required this.scheme,
    required this.brightness,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final FlexScheme scheme;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = FlexColor.schemes[scheme]!;
    final colors = brightness == Brightness.dark ? data.dark : data.light;
    final outline = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: context.l10n.colorThemeLabel(data.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? outline.primary : outline.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final c in [
                        colors.primary,
                        colors.secondary,
                        colors.tertiary,
                      ])
                        Expanded(
                          child: Container(
                            height: 28,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: selected ? 1 : 0,
                        child: Icon(
                          Icons.check_circle,
                          size: 18,
                          color: outline.primary,
                        ),
                      ),
                    ],
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

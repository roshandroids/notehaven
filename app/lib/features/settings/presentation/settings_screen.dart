import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/feedback/ui_feedback.dart';
import '../domain/app_settings.dart';
import 'settings_providers.dart';

/// Appearance settings: light/dark, color theme, font.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Every FlexColorScheme preset except the placeholder `custom`.
  static final _schemes = FlexScheme.values
      .where((s) => s != FlexScheme.custom)
      .toList(growable: false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final feedback = ref.read(feedbackProvider);
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SegmentedButton<ThemePreference>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemePreference.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemePreference.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemePreference.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {settings.themePreference},
                    onSelectionChanged: (s) {
                      feedback.play(FeedbackEvent.select);
                      controller.setThemePreference(s.first);
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ListTile(
                  leading: const Icon(Icons.font_download_outlined),
                  title: const Text('Font'),
                  subtitle: Text(settings.fontFamily ?? 'System default'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/font'),
                ),
              ),
              SliverToBoxAdapter(
                child: SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Haptic feedback'),
                  subtitle: const Text(
                    'Vibrate on actions (phones and tablets)',
                  ),
                  value: settings.hapticsEnabled,
                  onChanged: (v) {
                    controller.setHaptics(v);
                    if (v) feedback.play(FeedbackEvent.select);
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('Sounds'),
                  subtitle: const Text('Short tones for save, delete and undo'),
                  value: settings.soundsEnabled,
                  onChanged: (v) {
                    controller.setSounds(v);
                    // Preview so the toggle confirms itself.
                    if (v) feedback.play(FeedbackEvent.success);
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: ListTile(
                  leading: const Icon(Icons.animation),
                  title: const Text('Animations'),
                  subtitle: SegmentedButton<MotionPreference>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: MotionPreference.system,
                        label: Text('Follow system'),
                      ),
                      ButtonSegment(
                        value: MotionPreference.reduced,
                        label: Text('Reduced'),
                      ),
                    ],
                    selected: {settings.motion},
                    onSelectionChanged: (s) {
                      feedback.play(FeedbackEvent.select);
                      controller.setMotion(s.first);
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Color theme',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
        ),
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
      label: '${data.name} color theme',
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

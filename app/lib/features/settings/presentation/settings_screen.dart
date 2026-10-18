import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/feedback/ui_feedback.dart';
import '../domain/app_settings.dart';
import 'settings_providers.dart';

/// Settings: light/dark, color theme, font.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final feedback = ref.read(feedbackProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Color theme'),
                  subtitle: Text(
                    FlexColor.schemes[flexSchemeFor(settings.schemeName)]!.name,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/color'),
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
              const SliverToBoxAdapter(child: _AboutTile()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Version (top heading of the bundled changelog, kept equal to pubspec's
/// `version:` by the release workflow) with the full changelog on tap.
class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/CHANGELOG.md'),
      builder: (context, snap) {
        final log = snap.data ?? '';
        final version = RegExp(
          r'^## \[([^\]]+)\]',
          multiLine: true,
        ).firstMatch(log)?.group(1);
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          subtitle: Text(version == null ? 'Notehaven' : 'Version $version'),
          onTap: log.isEmpty
              ? null
              : () => showAboutDialog(
                  context: context,
                  applicationName: 'Notehaven',
                  applicationVersion: version,
                  children: [SelectableText(log)],
                ),
        );
      },
    );
  }
}

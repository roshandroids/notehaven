import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/feedback/ui_feedback.dart';
import '../../notes/presentation/note_actions.dart';
import '../../notes/presentation/note_providers.dart';
import '../domain/app_settings.dart';
import 'settings_providers.dart';
import 'storage_usage.dart';

/// Settings: light/dark, color theme, font.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final feedback = ref.read(feedbackProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(pinned: true, title: Text('Settings')),
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
                  leading: const Icon(Icons.grid_view_outlined),
                  title: const Text('Note layout'),
                  trailing: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.grid_view_outlined),
                        tooltip: 'Grid view',
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.view_agenda_outlined),
                        tooltip: 'List view',
                      ),
                    ],
                    selected: {ref.watch(gridViewProvider)},
                    onSelectionChanged: (s) {
                      feedback.play(FeedbackEvent.select);
                      if (s.first != ref.read(gridViewProvider)) {
                        ref.read(gridViewProvider.notifier).toggle();
                      }
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
              const SliverToBoxAdapter(child: _StorageTile()),
              const SliverToBoxAdapter(child: _DeleteAllTile()),
              const SliverToBoxAdapter(child: _AboutTile()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Local usage (notes vs. deletable cache) with a clear-cache button.
class _StorageTile extends ConsumerWidget {
  const _StorageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(storageUsageProvider).value;
    if (usage == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.storage_outlined),
      title: const Text('Storage'),
      subtitle: Text(
        'Notes ${formatBytes(usage.notes)} · Cache ${formatBytes(usage.cache)}',
      ),
      trailing: OutlinedButton(
        onPressed: usage.cache == 0
            ? null
            : () async {
                await clearCache();
                ref.invalidate(storageUsageProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Cache cleared')),
                  );
              },
        child: const Text('Clear cache'),
      ),
    );
  }
}

/// Deletes all notes after a confirmation; the snackbar offers undo.
class _DeleteAllTile extends ConsumerWidget {
  const _DeleteAllTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
      title: const Text('Delete all notes'),
      subtitle: const Text('Removes every note from this device'),
      onTap: () async {
        final actions = ref.read(noteActionsProvider);
        final messenger = ScaffoldMessenger.of(context);
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete all notes?'),
            content: const Text('You can undo right after.'),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete all'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final deleted = await actions.deleteAll();
        ref.invalidate(storageUsageProvider);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${deleted.length} notes deleted'),
              persist: false,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  for (final n in deleted) {
                    await actions.restore(n);
                  }
                },
              ),
            ),
          );
      },
    );
  }
}

/// Version (top heading of the bundled changelog, kept equal to pubspec's
/// `version:` by the release workflow) with the formatted changelog on tap.
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
          subtitle: Text(version == null ? 'Note Haven' : 'Version $version'),
          onTap: log.isEmpty
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => _AboutDialog(log: log),
                ),
        );
      },
    );
  }
}

/// Changelog markdown (## release, ### group, - item) as styled widgets.
class _AboutDialog extends StatelessWidget {
  const _AboutDialog({required this.log});

  final String log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (final line in log.split('\n')) {
      if (line.startsWith('## ')) {
        final m = RegExp(r'^## \[([^\]]+)\](?: - (.*))?').firstMatch(line);
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Chip(label: Text('v${m?.group(1) ?? line.substring(3)}')),
                const SizedBox(width: 8),
                if (m?.group(2) != null)
                  Text(m!.group(2)!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              line.substring(4),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(line.substring(2))),
              ],
            ),
          ),
        );
      }
    }
    return AlertDialog(
      icon: const Icon(Icons.edit_note, size: 40),
      title: const Text('Note Haven'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What\'s new', style: theme.textTheme.titleMedium),
              ...rows,
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

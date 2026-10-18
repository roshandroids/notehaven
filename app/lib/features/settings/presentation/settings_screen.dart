import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/feedback/ui_feedback.dart';
import '../../notes/presentation/note_actions.dart';
import '../../notes/presentation/note_providers.dart';
import '../domain/app_settings.dart';
import '../../../shared/crash/crash_log.dart';
import '../../../shared/feedback/custom_sounds.dart';
import '../../../shared/update/update_checker.dart';
import 'custom_sounds_dialog.dart';
import 'settings_providers.dart';
import 'storage_usage.dart';

/// Settings, grouped: appearance, feedback, data, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final feedback = ref.read(feedbackProvider);

    Widget item(Widget child) => SliverToBoxAdapter(child: child);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(pinned: true, title: Text('Settings')),
              const _Header('Appearance'),
              item(
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
              item(
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Color theme'),
                  subtitle: Text(
                    FlexColor.schemes[flexSchemeFor(settings.schemeName)]!.name,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/color'),
                ),
              ),
              item(
                ListTile(
                  leading: const Icon(Icons.font_download_outlined),
                  title: const Text('Font'),
                  subtitle: Text(settings.fontFamily ?? 'System default'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/font'),
                ),
              ),
              item(
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('Text size'),
                  subtitle: Slider(
                    value: settings.textScale,
                    min: 0.8,
                    max: 1.5,
                    divisions: 7,
                    label: '${(settings.textScale * 100).round()}%',
                    onChanged: controller.setTextScale,
                  ),
                  trailing: Text('${(settings.textScale * 100).round()}%'),
                ),
              ),
              item(
                ListTile(
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
              const _Header('Feedback'),
              item(
                SwitchListTile(
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
              item(
                SwitchListTile(
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
              if (settings.soundsEnabled && customSoundsSupported)
                item(
                  ListTile(
                    leading: const Icon(Icons.library_music_outlined),
                    title: const Text('Custom sounds'),
                    subtitle: const Text('Use your own audio files'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => const CustomSoundsDialog(),
                    ),
                  ),
                ),
              item(
                ListTile(
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
              const _Header('Data'),
              item(const _StorageTile()),
              item(const _DeleteAllTile()),
              const _Header('About'),
              item(const _AboutTile()),
              item(const _UpdateTile()),
              item(const _LicensesTile()),
              item(const _CrashTile()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Group label above a block of settings.
class _Header extends StatelessWidget {
  const _Header(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
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

/// Version = top heading of the bundled changelog (a test keeps it equal to
/// pubspec's `version:`).
final appVersionProvider = FutureProvider<String?>((ref) async {
  final log = await rootBundle.loadString('assets/CHANGELOG.md');
  return RegExp(r'^## \[([^\]]+)\]', multiLine: true).firstMatch(log)?.group(1);
});

/// Manual update check against the latest GitHub release.
class _UpdateTile extends ConsumerStatefulWidget {
  const _UpdateTile();

  @override
  ConsumerState<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends ConsumerState<_UpdateTile> {
  bool _checking = false;

  Future<void> _check() async {
    final messenger = ScaffoldMessenger.of(context);
    final current = await ref.read(appVersionProvider.future) ?? '0.0.0';
    setState(() => _checking = true);
    String? message;
    UpdateInfo? update;
    try {
      final latest = await fetchLatestRelease();
      if (latest != null && isNewerVersion(latest.version, current)) {
        update = latest;
      } else {
        message = latest == null
            ? 'No releases published yet'
            : 'You are up to date (v$current)';
      }
    } on Object {
      message = 'Could not check for updates. Try again later.';
    }
    if (!mounted) return;
    setState(() => _checking = false);
    if (update == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message!), persist: false));
      return;
    }
    final found = update;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.system_update_alt, size: 40),
        title: Text('Version ${found.version} is available'),
        content: Text('You have v$current.'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              launchUrl(Uri.parse(found.url));
              Navigator.pop(context);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.system_update_alt),
    title: const Text('Check for updates'),
    trailing: _checking
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    onTap: _checking ? null : _check,
  );
}

/// Flutter's license page (every package) plus the extras registered in
/// `registerExtraLicenses`.
class _LicensesTile extends ConsumerWidget {
  const _LicensesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.gavel_outlined),
    title: const Text('Licenses'),
    subtitle: const Text('Open-source licenses'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => showLicensePage(
      context: context,
      applicationName: 'Note Haven',
      applicationVersion: ref.read(appVersionProvider).value,
      applicationLegalese: '© 2026 Notehaven contributors · MIT License',
    ),
  );
}

final crashEntriesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.read(crashLogProvider).entries(),
);

/// Errors recorded on this device; viewable, shareable and clearable.
class _CrashTile extends ConsumerWidget {
  const _CrashTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.read(crashLogProvider);
    final entries = ref.watch(crashEntriesProvider).value ?? const <String>[];
    return ListTile(
      leading: const Icon(Icons.bug_report_outlined),
      title: const Text('Error reports'),
      subtitle: Text(
        entries.isEmpty
            ? 'No errors recorded'
            : '${entries.length} recorded on this device',
      ),
      onTap: entries.isEmpty
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Error reports'),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      entries.join('\n\n---\n\n'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () async {
                      await log.clear();
                      ref.invalidate(crashEntriesProvider);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                  FilledButton(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: entries.join('\n\n---\n\n'),
                        subject: 'Note Haven error report',
                      ),
                    ),
                    child: const Text('Share'),
                  ),
                ],
              ),
            ),
    );
  }
}

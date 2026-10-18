import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/feedback/custom_sounds.dart';
import '../../../shared/feedback/ui_feedback.dart';
import '../../../l10n/l10n.dart';

String _label(AppLocalizations l10n, FeedbackEvent e) => switch (e) {
  FeedbackEvent.success => l10n.soundSaved,
  FeedbackEvent.delete => l10n.soundDeleted,
  FeedbackEvent.undo => l10n.undo,
  _ => l10n.soundError,
};

/// Per-event choice between the built-in tone and a user audio file.
class CustomSoundsDialog extends ConsumerStatefulWidget {
  const CustomSoundsDialog({super.key});

  @override
  ConsumerState<CustomSoundsDialog> createState() => _CustomSoundsDialogState();
}

class _CustomSoundsDialogState extends ConsumerState<CustomSoundsDialog> {
  Future<void> _pick(FeedbackEvent event) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await pickCustomSound(event) != null) {
        ref.read(feedbackProvider).play(event);
      }
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          persist: false,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.customSounds),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final event in customizableEvents)
            FutureBuilder(
              future: customSoundFor(event),
              builder: (context, snap) {
                final file = snap.data;
                final l10n = context.l10n;
                return ListTile(
                  title: Text(_label(l10n, event)),
                  subtitle: Text(
                    file == null
                        ? l10n.defaultTone
                        : file.uri.pathSegments.last,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.outlined(
                        tooltip: l10n.playSound(_label(l10n, event)),
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => ref.read(feedbackProvider).play(event),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: l10n.chooseSound(_label(l10n, event)),
                        icon: const Icon(Icons.folder_open),
                        onPressed: () => _pick(event),
                      ),
                      if (file != null) ...[
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: l10n.resetSound(_label(l10n, event)),
                          icon: const Icon(Icons.restart_alt),
                          onPressed: () async {
                            await resetCustomSound(event);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.done),
      ),
    ],
  );
}

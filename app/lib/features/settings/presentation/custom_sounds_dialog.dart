import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/feedback/custom_sounds.dart';
import '../../../shared/feedback/ui_feedback.dart';

const _labels = {
  FeedbackEvent.success: 'Saved',
  FeedbackEvent.delete: 'Deleted',
  FeedbackEvent.undo: 'Undo',
  FeedbackEvent.error: 'Error',
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
    title: const Text('Custom sounds'),
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
                return ListTile(
                  title: Text(_labels[event]!),
                  subtitle: Text(
                    file == null ? 'Default tone' : file.uri.pathSegments.last,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.outlined(
                        tooltip: 'Play ${_labels[event]} sound',
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => ref.read(feedbackProvider).play(event),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Choose ${_labels[event]} sound',
                        icon: const Icon(Icons.folder_open),
                        onPressed: () => _pick(event),
                      ),
                      if (file != null) ...[
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: 'Reset ${_labels[event]} sound',
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
        child: const Text('Done'),
      ),
    ],
  );
}

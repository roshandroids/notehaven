import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:notehaven_sync/notehaven_sync.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../shared/layout/layout.dart';
import '../../../l10n/l10n.dart';

/// App-bar sync indicator; hidden when no backend is configured. Tap to sync
/// now (the tooltip is also the screen-reader label).
class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduler = ref.watch(syncSchedulerProvider);
    if (scheduler == null) return const SizedBox.shrink();
    final status = ref.watch(syncStatusProvider).value ?? scheduler.status;
    final l10n = context.l10n;
    final (icon, tooltip) = switch (status.state) {
      SyncState.syncing => (Icons.sync, l10n.syncing),
      SyncState.failed => (Icons.sync_problem, l10n.syncFailed),
      SyncState.idle => (
        Icons.cloud_done_outlined,
        status.lastSyncedAt == null
            ? l10n.tapToSync
            : l10n.syncedAt(
                DateFormat.jm(l10n.localeName).format(status.lastSyncedAt!),
              ),
      ),
    };
    final syncing = status.state == SyncState.syncing;
    final glyph = Icon(icon, key: ValueKey(status.state));
    return IconButton.outlined(
      tooltip: tooltip,
      // Spin while syncing; cross-fade between states. State is also in the
      // tooltip, so nothing depends on the motion.
      icon: reduceMotion(context)
          ? glyph
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: syncing
                  ? glyph
                        .animate(onPlay: (c) => c.repeat())
                        .rotate(duration: 1200.ms)
                  : glyph,
            ),
      onPressed: status.state == SyncState.syncing ? null : scheduler.syncNow,
    );
  }
}

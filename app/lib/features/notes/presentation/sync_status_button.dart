import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:notehaven_sync/notehaven_sync.dart';

import '../../../core/sync/sync_providers.dart';

/// App-bar sync indicator; hidden when no backend is configured. Tap to sync
/// now (the tooltip is also the screen-reader label).
class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduler = ref.watch(syncSchedulerProvider);
    if (scheduler == null) return const SizedBox.shrink();
    final status = ref.watch(syncStatusProvider).value ?? scheduler.status;
    final (icon, tooltip) = switch (status.state) {
      SyncState.syncing => (Icons.sync, 'Syncing…'),
      SyncState.failed => (
        Icons.sync_problem,
        'Sync failed, will retry. Tap to retry now.',
      ),
      SyncState.idle => (
        Icons.cloud_done_outlined,
        status.lastSyncedAt == null
            ? 'Tap to sync now'
            : 'Synced ${DateFormat.jm().format(status.lastSyncedAt!)}. Tap to sync now.',
      ),
    };
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: status.state == SyncState.syncing ? null : scheduler.syncNow,
    );
  }
}

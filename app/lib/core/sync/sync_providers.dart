import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notehaven_sync/notehaven_sync.dart';

/// The running sync scheduler, or null when no backend is configured (the
/// template ships without one, so sync is off by default).
final syncSchedulerProvider = Provider<SyncScheduler?>((ref) => null);

/// Live sync status; empty when sync is off.
final syncStatusProvider = StreamProvider.autoDispose<SyncStatus>((ref) async* {
  final scheduler = ref.watch(syncSchedulerProvider);
  if (scheduler == null) return;
  yield scheduler.status;
  yield* scheduler.statuses;
});

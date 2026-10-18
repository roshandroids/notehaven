import 'dart:async';

import 'sync_engine.dart';

/// Coarse state for a status indicator.
enum SyncState { idle, syncing, failed }

/// Snapshot of the scheduler for the UI.
class SyncStatus {
  const SyncStatus({
    required this.state,
    this.lastSyncedAt,
    this.lastError,
    this.consecutiveFailures = 0,
  });

  final SyncState state;
  final DateTime? lastSyncedAt;
  final Object? lastError;
  final int consecutiveFailures;
}

/// Decides *when* to run the engine: soon after local writes (debounced), on
/// a slow timer, and with exponential backoff after failures.
///
/// shortcut: no connectivity or app-lifecycle triggers; call [requestSync]
/// from them when you add `connectivity_plus` or resume handling.
class SyncScheduler {
  SyncScheduler(
    this._engine, {
    this.debounce = const Duration(seconds: 2),
    this.interval = const Duration(seconds: 60),
    this.baseBackoff = const Duration(seconds: 5),
    this.maxBackoff = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SyncEngine _engine;
  final Duration debounce;
  final Duration interval;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final DateTime Function() _clock;

  final _controller = StreamController<SyncStatus>.broadcast();
  Timer? _timer;
  var _started = false;
  var _syncing = false;
  var _dirty = false;
  var _failures = 0;
  SyncStatus _status = const SyncStatus(state: SyncState.idle);

  /// Current status.
  SyncStatus get status => _status;

  /// Status changes.
  Stream<SyncStatus> get statuses => _controller.stream;

  /// Starts syncing now and then periodically.
  void start() {
    if (_started) return;
    _started = true;
    _schedule(Duration.zero);
  }

  /// Stops all timers; an in-flight run finishes but nothing new starts.
  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Call after a local write: syncs after [debounce] of quiet.
  void requestSync() {
    if (!_started) return;
    if (_syncing) {
      _dirty = true;
      return;
    }
    _schedule(debounce);
  }

  /// Runs a sync immediately (for a "Sync now" button).
  Future<void> syncNow() => _run();

  /// Releases the status stream; call after [stop].
  Future<void> dispose() {
    stop();
    return _controller.close();
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  Duration get _backoff {
    final factor = 1 << (_failures - 1).clamp(0, 20);
    final delay = baseBackoff * factor;
    return delay > maxBackoff ? maxBackoff : delay;
  }

  void _emit(SyncStatus s) {
    _status = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  Future<void> _run() async {
    if (_syncing) return;
    _timer?.cancel();
    _syncing = true;
    _emit(
      SyncStatus(
        state: SyncState.syncing,
        lastSyncedAt: _status.lastSyncedAt,
        lastError: _status.lastError,
        consecutiveFailures: _failures,
      ),
    );
    final report = await _engine.syncOnce();
    _syncing = false;
    if (report.ok) {
      _failures = 0;
      _emit(SyncStatus(state: SyncState.idle, lastSyncedAt: _clock()));
    } else {
      _failures++;
      _emit(
        SyncStatus(
          state: SyncState.failed,
          lastSyncedAt: _status.lastSyncedAt,
          lastError: report.error,
          consecutiveFailures: _failures,
        ),
      );
    }
    if (!_started) return;
    if (_dirty && report.ok) {
      _dirty = false;
      _schedule(debounce);
    } else {
      _schedule(report.ok ? interval : _backoff);
    }
  }
}

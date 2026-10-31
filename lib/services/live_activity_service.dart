import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/app_logger.dart';

/// Snapshot of aggregate download activity shown in the iOS Live Activity
/// (lock screen / Dynamic Island). This is presentation data for a system
/// surface, not app state — deliberately a separate, smaller shape than
/// anything [DownloadProvider] keeps for itself.
class LiveActivityDownloadState {
  const LiveActivityDownloadState({
    required this.activeCount,
    required this.queuedCount,
    required this.overallProgress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytesPerSec,
    this.primaryTitle,
  });

  final int activeCount;
  final int queuedCount;

  /// 0.0-1.0 across every active/queued download.
  final double overallProgress;
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSec;

  /// Title of one representative active download, for display alongside the
  /// aggregate counters. Null when nothing is actively downloading yet.
  final String? primaryTitle;

  bool get isIdle => activeCount == 0 && queuedCount == 0;

  Map<String, Object?> toChannelMap() => {
    'activeCount': activeCount,
    'queuedCount': queuedCount,
    'overallProgress': overallProgress,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'speedBytesPerSec': speedBytesPerSec,
    'primaryTitle': primaryTitle,
  };
}

/// Starts, updates, and ends the iOS Live Activity that mirrors active
/// downloads on the lock screen and in the Dynamic Island, so progress stays
/// visible (and downloads stay anchored) while the app is backgrounded.
///
/// A no-op on every platform other than iOS, and on iOS versions below 16.1
/// — the native side reports `isSupported: false` and every call
/// short-circuits before touching the platform channel.
///
/// Live Activity updates are rate-limited by the OS, so calls are throttled
/// to at most one native update per [_minUpdateInterval]; the most recent
/// state always wins once the throttle window elapses.
class LiveActivityService {
  LiveActivityService._();

  static final LiveActivityService instance = LiveActivityService._();

  static const _channel = MethodChannel('com.plezy/live_activity');
  static const _minUpdateInterval = Duration(seconds: 1);

  bool? _supported;
  bool _started = false;
  DateTime? _lastSentAt;
  Timer? _pendingTimer;
  LiveActivityDownloadState? _pendingState;

  Future<bool> _isSupported() async {
    if (!Platform.isIOS) return false;
    final cached = _supported;
    if (cached != null) return cached;
    bool supported;
    try {
      supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (e) {
      appLogger.d('Live Activity support probe failed', error: e);
      supported = false;
    }
    _supported = supported;
    return supported;
  }

  /// Reconciles the Live Activity with [state]: starts one if none is active
  /// yet and there's activity to show, updates it while active, and ends it
  /// once [state] goes idle.
  Future<void> syncState(LiveActivityDownloadState state) async {
    if (!await _isSupported()) return;

    if (state.isIdle) {
      _pendingTimer?.cancel();
      _pendingTimer = null;
      _pendingState = null;
      if (_started) {
        _started = false;
        await _invoke('end', const {});
      }
      return;
    }

    _pendingState = state;
    final now = DateTime.now();
    final lastSentAt = _lastSentAt;
    if (lastSentAt != null && now.difference(lastSentAt) < _minUpdateInterval) {
      _pendingTimer ??= Timer(_minUpdateInterval - now.difference(lastSentAt), _flushPending);
      return;
    }
    await _sendNow(state);
  }

  void _flushPending() {
    _pendingTimer = null;
    final state = _pendingState;
    if (state != null) unawaited(_sendNow(state));
  }

  Future<void> _sendNow(LiveActivityDownloadState state) async {
    _lastSentAt = DateTime.now();
    _pendingState = null;
    if (!_started) {
      _started = true;
      await _invoke('start', state.toChannelMap());
    } else {
      await _invoke('update', state.toChannelMap());
    }
  }

  /// Ends the Live Activity unconditionally — used on provider teardown
  /// (profile switch, sign-out) so a stale activity never outlives its owner.
  Future<void> endAll() async {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pendingState = null;
    if (!_started) return;
    _started = false;
    await _invoke('end', const {});
  }

  Future<void> _invoke(String method, Map<String, Object?> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      appLogger.d('Live Activity $method failed', error: e);
    }
  }
}

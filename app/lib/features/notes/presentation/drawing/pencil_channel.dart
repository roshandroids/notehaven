import 'package:flutter/services.dart';

/// Apple Pencil double-tap / squeeze, forwarded by `PencilBridge.swift`.
/// Silent on platforms without a Pencil (the native side never calls).
class PencilChannel {
  static const _channel = MethodChannel('notehaven/pencil');

  /// Calls [onAction] for each Pencil tap or squeeze until [detach].
  static void attach(VoidCallback onAction) =>
      _channel.setMethodCallHandler((call) async => onAction());

  static void detach() => _channel.setMethodCallHandler(null);
}

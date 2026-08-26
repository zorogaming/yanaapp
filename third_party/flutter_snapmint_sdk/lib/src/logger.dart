import 'package:flutter/foundation.dart';

/// A simple logger that only logs in debug mode and stays silent in production.
class SnapmintLogger {
  /// Logs a message with a timestamp, but only in debug mode.
  /// In production builds, this method does nothing.
  static void log(String message) {
    if (kDebugMode) {
      final now = DateTime.now();
      final timestamp = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}:'
          '${now.millisecond.toString().padLeft(3, '0')}';
      debugPrint('[$timestamp] $message');
    }
  }
}

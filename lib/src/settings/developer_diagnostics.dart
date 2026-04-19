import 'package:flutter/foundation.dart';

class DeveloperDiagnostics {
  static bool _timingLogsEnabled = false;

  static bool get timingLogsEnabled => _timingLogsEnabled;

  static void setTimingLogsEnabled(bool enabled) {
    _timingLogsEnabled = enabled;
  }

  static void logTiming(String scope, String message) {
    if (!_timingLogsEnabled) {
      return;
    }

    debugPrint('[timing][$scope] $message');
  }

  static void logTimingError(String scope, Object error, [StackTrace? stackTrace]) {
    if (!_timingLogsEnabled) {
      return;
    }

    debugPrint('[timing][$scope] error=$error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

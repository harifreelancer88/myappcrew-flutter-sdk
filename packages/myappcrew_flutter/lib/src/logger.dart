import 'package:flutter/foundation.dart';

class MyAppCrewLogger {
  MyAppCrewLogger(this.debugLogs);

  final bool debugLogs;

  void log(String message) {
    if (!debugLogs || !kDebugMode) {
      return;
    }
    debugPrint('[MyAppCrew] $message');
  }
}

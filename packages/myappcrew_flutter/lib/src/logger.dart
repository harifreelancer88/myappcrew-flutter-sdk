import 'package:flutter/foundation.dart';

class MyAppCrewLogger {
  MyAppCrewLogger(this.debugLogs);

  final bool debugLogs;

  void log(String message) {
    if (!debugLogs) {
      return;
    }
    // debugPrint is safe in release when explicitly enabled.
    debugPrint('[MyAppCrew] $message');
  }
}

import 'package:flutter/widgets.dart';

class MyAppCrewLifecycleObserver extends WidgetsBindingObserver {
  MyAppCrewLifecycleObserver({
    required this.onBackground,
    required this.onForeground,
  });

  final VoidCallback onBackground;
  final VoidCallback onForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      onBackground();
    } else if (state == AppLifecycleState.resumed) {
      onForeground();
    }
  }
}

import 'package:flutter/widgets.dart';

class MyAppCrewLifecycleObserver extends WidgetsBindingObserver {
  MyAppCrewLifecycleObserver({required this.onBackground});

  final VoidCallback onBackground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      onBackground();
    }
  }
}

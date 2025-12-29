import 'package:flutter/widgets.dart';

class MyAppCrewNavigatorObserver extends NavigatorObserver {
  MyAppCrewNavigatorObserver({
    required this.onScreenChange,
    this.unknownRouteNameFallback = 'unknown',
  });

  final String unknownRouteNameFallback;
  final void Function(String screenName) onScreenChange;

  String? _currentScreen;

  String? get currentScreen => _currentScreen;

  void _handleRoute(Route<dynamic>? route) {
    if (route == null) {
      return;
    }
    final settingsName = route.settings.name;
    final name = settingsName == null || settingsName.isEmpty
        ? unknownRouteNameFallback
        : settingsName;
    if (_currentScreen == name) {
      return;
    }
    _currentScreen = name;
    onScreenChange(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _handleRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _handleRoute(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _handleRoute(previousRoute);
    super.didPop(route, previousRoute);
  }
}

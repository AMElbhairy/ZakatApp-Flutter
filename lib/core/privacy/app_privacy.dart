import 'package:flutter/material.dart';

enum ScreenPrivacyClassification { sensitive, nonSensitive }

class AppPrivacyRouteSettings extends RouteSettings {
  const AppPrivacyRouteSettings({
    super.name,
    super.arguments,
    required this.privacy,
  });

  final ScreenPrivacyClassification privacy;
}

class PrivacyRouteObserver extends NavigatorObserver {
  PrivacyRouteObserver(this.onPrivacyChanged);

  final ValueChanged<ScreenPrivacyClassification?> onPrivacyChanged;

  void _sync(Route<dynamic>? route) {
    final RouteSettings? settings = route?.settings;
    if (settings is AppPrivacyRouteSettings) {
      onPrivacyChanged(settings.privacy);
    } else {
      onPrivacyChanged(null);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sync(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sync(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _sync(newRoute);
  }
}

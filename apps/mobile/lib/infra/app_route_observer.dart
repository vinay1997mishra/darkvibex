// Tracks the top route name so problem reports and crash reports can
// say which screen the user was on (Mr. Wrong, 2026-11-24).
import 'package:flutter/material.dart';

class AppRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  static String currentRouteName = '';

  static String _name(Route<dynamic>? route) {
    final settings = route?.settings;
    if (settings?.name != null && settings!.name!.isNotEmpty) {
      return settings.name!;
    }
    // Most pushes in this app use MaterialPageRoute without a name;
    // fall back to the page widget type so the screen is still known.
    final routeType = route?.runtimeType.toString() ?? '';
    if (routeType.isNotEmpty) return routeType;
    return '';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = _name(route);
    if (name.isNotEmpty) currentRouteName = name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = _name(previousRoute);
    if (name.isNotEmpty) currentRouteName = name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final name = _name(newRoute);
    if (name.isNotEmpty) currentRouteName = name;
  }
}

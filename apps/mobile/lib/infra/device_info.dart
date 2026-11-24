// Device + app info that rides along with every problem report and
// crash report (Mr. Wrong, 2026-11-24). Never throws: when a plugin is
// unavailable (tests, old devices) the map still comes back with
// 'unknown' values, so reporting never breaks the app.
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_route_observer.dart';

/// Human-readable one-line summary, e.g.
/// "Pixel 8, Android 14, app 0.1.0 (1), screen FamilyDetail".
String deviceInfoSummary(Map<String, String> info) {
  final parts = <String>[
    if (info['model'] != null && info['model']!.isNotEmpty) info['model']!,
    if (info['os'] != null && info['os']!.isNotEmpty) info['os']!,
    if (info['app_version'] != null && info['app_version']!.isNotEmpty)
      'app ${info['app_version']}',
    if (info['route'] != null && info['route']!.isNotEmpty)
      'screen ${info['route']}',
  ];
  return parts.isEmpty ? 'unknown device' : parts.join(', ');
}

Future<Map<String, String>> collectDeviceInfo({String? route}) async {
  final info = <String, String>{
    'model': 'unknown',
    'os': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'app_version': 'unknown',
    'app_build': '',
    'route': route ?? AppRouteObserver.currentRouteName,
  };
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    info['app_version'] = packageInfo.version;
    info['app_build'] = packageInfo.buildNumber;
  } catch (_) {
    // Tests / unavailable plugin: keep 'unknown'.
  }
  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      info['model'] = android.model;
      info['os'] = 'Android ${android.version.release}';
      info['os_version'] = 'SDK ${android.version.sdkInt}';
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      info['model'] = ios.utsname.machine;
      info['os'] = '${ios.systemName} ${ios.systemVersion}';
    }
  } catch (_) {
    // Tests / unavailable plugin: keep the dart:io fallbacks.
  }
  return info;
}

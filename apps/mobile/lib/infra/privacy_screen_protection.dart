import 'package:flutter/services.dart';

class PrivacyScreenProtection {
  PrivacyScreenProtection._();

  static const MethodChannel _channel = MethodChannel('darkvibex/privacy');
  static final Set<Object> _protectedViews = <Object>{};

  static Future<void> setProtected(Object scope, bool protected) async {
    if (protected) {
      _protectedViews.add(scope);
    } else {
      _protectedViews.remove(scope);
    }
    try {
      await _channel.invokeMethod<void>('setSecure', <String, Object>{
        'enabled': _protectedViews.isNotEmpty,
      });
    } on MissingPluginException {
      // Platform capture protection is only available on Android.
    } on PlatformException {
      // Keep the profile usable if the native window cannot be updated.
    }
  }
}

import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_config.dart';
import 'local_store.dart';

class DeviceTelemetry {
  const DeviceTelemetry({
    required this.clientDeviceId,
    required this.platform,
    required this.osName,
    required this.osVersion,
    required this.manufacturer,
    required this.model,
    required this.appVersion,
  });

  final String  clientDeviceId;
  final String  platform;
  final String? osName;
  final String? osVersion;
  final String? manufacturer;
  final String? model;
  final String  appVersion;
}

Future<DeviceTelemetry> getDeviceTelemetry() async {
  var clientDeviceId = await LocalStore.getDeviceId();

  if (clientDeviceId == null || clientDeviceId.isEmpty) {
    clientDeviceId = const Uuid().v4();
    await LocalStore.setDeviceId(clientDeviceId);
  }

  var     platform     = 'android';
  String? osName;
  String? osVersion;
  String? manufacturer;
  String? model;

  try {
    final plugin = DeviceInfoPlugin();

    if (kIsWeb) {
      // الويب: قيم قصيرة بس (السيرفر بيرفض أي حقل أطول من 64 حرف)
      final info = await plugin.webBrowserInfo;
      final ua = info.userAgent ?? '';
      platform     = 'web';
      osName       = _webOs(ua);
      osVersion    = null;
      manufacturer = info.vendor;
      model        = info.browserName.name;
    } else if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      platform     = 'android';
      osName       = 'Android';
      osVersion    = info.version.release;
      manufacturer = info.manufacturer;
      model        = info.model;
    } else if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      platform     = 'ios';
      osName       = info.systemName;
      osVersion    = info.systemVersion;
      manufacturer = 'Apple';
      model        = info.utsname.machine;
    }
  } catch (e) {
    debugPrint('Device information unavailable: $e');
  }

  return DeviceTelemetry(
    clientDeviceId: clientDeviceId,
    platform:       platform,
    osName:         _cap(osName),
    osVersion:      _cap(osVersion),
    manufacturer:   _cap(manufacturer),
    model:          _cap(model),
    appVersion:     AppConfig.appVersion,
  );
}


/// السيرفر (assert_device_input) بيقبل 64 حرف بس لكل حقل
String? _cap(String? s) {
  if (s == null) return null;
  final v = s.trim();
  if (v.isEmpty) return null;
  return v.length > 64 ? v.substring(0, 64) : v;
}

/// اسم نظام التشغيل من الـ user agent (ويب)
String _webOs(String ua) {
  final android = RegExp(r'Android [\d.]+').firstMatch(ua);
  if (android != null) return android.group(0)!;
  if (RegExp(r'iPhone|iPad|iPod').hasMatch(ua)) return 'iOS';
  if (ua.contains('Windows')) return 'Windows';
  if (ua.contains('Mac OS X') || ua.contains('Macintosh')) return 'macOS';
  if (ua.contains('CrOS')) return 'ChromeOS';
  if (ua.contains('Linux')) return 'Linux';
  return 'Web';
}

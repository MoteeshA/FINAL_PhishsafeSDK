import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoLogger {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return {
        'platform': 'Android',
        'brand': info.brand,
        'model': info.model,
        'manufacturer': info.manufacturer,
        'version': info.version.release,
        'sdk_int': info.version.sdkInt,
      };
    } else if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return {
        'platform': 'iOS',
        'name': info.name,
        'model': info.model,
        'systemVersion': info.systemVersion,
        'identifierForVendor': info.identifierForVendor,
      };
    } else {
      return {'platform': 'Unknown'};
    }
  }
}

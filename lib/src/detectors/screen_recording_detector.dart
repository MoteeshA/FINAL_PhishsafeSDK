import 'dart:io';

import 'package:flutter/services.dart';

class ScreenRecordingDetector {
  static const MethodChannel _channel =
  MethodChannel('phishsafe_sdk/screen_recording');

  /// Returns true if screen recording is active
  Future<bool> isScreenRecording() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isScreenRecording');
      return result ?? false;
    } catch (e) {
      print('Screen recording detection failed: $e');
      return false;
    }
  }
}

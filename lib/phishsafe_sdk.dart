
library phishsafe_sdk;

export 'src/phishsafe_tracker_manager.dart';

// Integrations
export 'src/integrations/gesture_wrapper.dart';

// Trackers
export 'src/trackers/location_tracker.dart';
export 'src/trackers/navigation_logger.dart';
export 'src/trackers/interaction/tap_tracker.dart';
export 'src/trackers/interaction/swipe_tracker.dart';

// Detectors
export 'src/detectors/suspicious_behavior_detector.dart';
export 'src/detectors/screen_recording_detector.dart';

// Analytics
export 'src/analytics/session_tracker.dart';
export 'src/analytics/user_profile_builder.dart';

// Device
export 'src/device/device_info_logger.dart';
export 'src/device/security_checker.dart';

// Storage
export 'storage/local_storage.dart';
export 'storage/export_manager.dart';

import 'src/phishsafe_tracker_manager.dart';

/// Public-facing class that wraps the internal tracker manager.
/// This is what app developers will use.
class PhishSafeSDK {
  static final _manager = PhishSafeTrackerManager();

  static void initSession() => _manager.startSession();

  static Future<void> endSession() => _manager.endSessionAndExport();

  static void onTap(String screen) => _manager.onTap(screen);

  static void onSwipeStart(double pos) => _manager.onSwipeStart(pos);

  static void onSwipeEnd(double pos) => _manager.onSwipeEnd(pos);

  static void onScreenVisit(String screen) => _manager.onScreenVisited(screen);

  static void onScreenExit(String screen) {
    print("Exited screen: $screen");
  }
  static void logScreenDuration(String screen, int seconds) =>
      _manager.recordScreenDuration(screen, seconds);

}

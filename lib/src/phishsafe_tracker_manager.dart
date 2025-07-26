import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// Trackers
import 'trackers/interaction/tap_tracker.dart';
import 'trackers/interaction/swipe_tracker.dart';
import 'trackers/interaction/input_tracker.dart';
import 'trackers/location_tracker.dart';
import 'trackers/navigation_logger.dart';

// Session & Utils
import 'analytics/session_tracker.dart';
import 'device/device_info_logger.dart';
import '../storage/export_manager.dart';
import 'detectors/screen_recording_detector.dart';

/// Helper function to map tap local position to a 3x3 zone grid.
///
/// Takes the local tap position relative to the widget and the widget size,
/// returns a zone string like "top_left", "center", etc.
String getTapZone(Offset localPosition, Size widgetSize) {
  final zoneWidth = widgetSize.width / 3;
  final zoneHeight = widgetSize.height / 3;

  int col = (localPosition.dx / zoneWidth).floor().clamp(0, 2);
  int row = (localPosition.dy / zoneHeight).floor().clamp(0, 2);

  const zoneMap = {
    0: {
      0: 'top_left',
      1: 'top_center',
      2: 'top_right',
    },
    1: {
      0: 'middle_left',
      1: 'center',
      2: 'middle_right',
    },
    2: {
      0: 'bottom_left',
      1: 'bottom_center',
      2: 'bottom_right',
    },
  };

  return zoneMap[row]?[col] ?? 'unknown';
}

class PhishSafeTrackerManager {
  // Singleton pattern
  static final PhishSafeTrackerManager _instance = PhishSafeTrackerManager._internal();
  factory PhishSafeTrackerManager() => _instance;
  PhishSafeTrackerManager._internal();

  // Trackers
  final TapTracker _tapTracker = TapTracker();
  final SwipeTracker _swipeTracker = SwipeTracker();
  final NavigationLogger _navLogger = NavigationLogger();
  final LocationTracker _locationTracker = LocationTracker();
  final SessionTracker _sessionTracker = SessionTracker();
  final DeviceInfoLogger _deviceLogger = DeviceInfoLogger();
  final ExportManager _exportManager = ExportManager();
  final InputTracker _inputTracker = InputTracker();

  final Map<String, int> _screenDurations = {};
  Timer? _screenRecordingTimer;
  bool _screenRecordingDetected = false;
  BuildContext? _context;

  // Provide context to show dialogs
  void setContext(BuildContext context) {
    _context = context;
  }

  // Start a new session
  void startSession() {
    _tapTracker.reset();
    _swipeTracker.reset();
    _navLogger.reset();
    _sessionTracker.startSession();
    _inputTracker.reset();
    _inputTracker.markLogin();
    _screenRecordingDetected = false;
    _screenDurations.clear();

    print("✅ PhishSafe session started");

    _screenRecordingTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      final isRecording = await ScreenRecordingDetector().isScreenRecording();
      if (isRecording && !_screenRecordingDetected) {
        _screenRecordingDetected = true;
        print("🚨 Screen recording detected");

        if (_context != null) {
          showDialog(
            context: _context!,
            builder: (ctx) => AlertDialog(
              title: Text("⚠️ Security Warning"),
              content: Text("Screen recording is active. Please disable it to protect your banking session."),
              actions: [
                TextButton(
                  child: Text("OK"),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  // Keep track of screen usage
  void recordScreenDuration(String screen, int seconds) {
    _screenDurations[screen] = (_screenDurations[screen] ?? 0) + seconds;
    print("📺 Screen duration recorded: $screen → $seconds seconds");
  }

  // Basic tap tracking (fallback)
  void onTap(String screen) => _tapTracker.recordTap(
    screenName: screen,
    tapPosition: Offset.zero,
    tapZone: 'unknown',
  );

  /// Tap tracking WITH position and zone.
  void recordTapPosition({
    required String screenName,
    required Offset tapPosition,
    required String tapZone,
  }) {
    _tapTracker.recordTap(screenName: screenName, tapPosition: tapPosition, tapZone: tapZone);
    print("📌 Tap recorded at $tapPosition on $screenName in zone $tapZone");
  }

  void onSwipeStart(double pos) => _swipeTracker.startSwipe(pos);
  void onSwipeEnd(double pos) => _swipeTracker.endSwipe(pos);
  void onScreenVisited(String screen) => _navLogger.logVisit(screen);

  // Record within bank transfer amount only
  void recordWithinBankTransferAmount(String amount) {
    _inputTracker.setTransactionAmount(amount);
    print("💰 Within-bank transfer amount tracked: $amount");
  }

  // Mark FD as broken
  void recordFDBroken() {
    _inputTracker.markFDBroken();
    print("🧨 FD broken marked");
  }

  // Mark loan as taken
  void recordLoanTaken() {
    _inputTracker.markLoanTaken();
    print("📋 Loan application recorded");
  }

  // MARK: Methods to mark transaction start and end - call these from your app UI flow
  void markTransactionStart() {
    _inputTracker.markTransactionStart();
    print("🏁 Transaction started");
  }

  void markTransactionEnd() {
    _inputTracker.markTransactionEnd();
    print("✅ Transaction ended");
  }

  // End session and export to JSON with tap event filtering and deduplication
  Future<void> endSessionAndExport() async {
    _sessionTracker.endSession();
    _screenRecordingTimer?.cancel();
    _screenRecordingTimer = null;

    final Position? location = await _locationTracker.getCurrentLocation();
    final deviceInfo = await _deviceLogger.getDeviceInfo();
    final sessionDuration = _sessionTracker.sessionDuration?.inSeconds ?? 0;

    final allTapEvents = _tapTracker.getTapEvents();
    final allSwipeEvents = _swipeTracker.getSwipeEvents();
    final screenVisits = _navLogger.logs;

    // Filter tap events to exclude those with zero position or unknown zone
    final filteredTapEvents = allTapEvents.where((tap) {
      final pos = tap['position'];
      final zone = tap['zone'];
      if (pos == null || zone == null) return false;
      if (pos['dx'] == 0.0 && pos['dy'] == 0.0) return false;
      if (zone == 'unknown') return false;
      return true;
    }).toList();

    // Optional: deduplicate tap events (same screen, same position, very close timestamp)
    final dedupedTapEvents = <Map<String, dynamic>>[];
    for (var tap in filteredTapEvents) {
      bool duplicateFound = dedupedTapEvents.any((existingTap) {
        if (existingTap['screen'] != tap['screen']) return false;
        if (existingTap['zone'] != tap['zone']) return false;
        if (existingTap['position'] == null || tap['position'] == null) return false;
        if (existingTap['position']['dx'] != tap['position']['dx']) return false;
        if (existingTap['position']['dy'] != tap['position']['dy']) return false;
        final existingTime = DateTime.tryParse(existingTap['timestamp'] ?? '');
        final tapTime = DateTime.tryParse(tap['timestamp'] ?? '');
        if (existingTime == null || tapTime == null) return false;
        final diff = existingTime.difference(tapTime).inMilliseconds.abs();
        return diff <= 300; // Consider taps within 300ms at same pos duplicate
      });
      if (!duplicateFound) {
        dedupedTapEvents.add(tap);
      }
    }

    // Enrich tap/swipe into screen visits with filtered and deduplicated taps
    final enrichedScreenVisits = screenVisits.map((visit) {
      final screenName = visit['screen'];
      final visitTime = DateTime.tryParse(visit['timestamp'] ?? '');

      final relatedTaps = dedupedTapEvents.where((tap) {
        final tapTime = DateTime.tryParse(tap['timestamp']);
        if (tapTime == null || visitTime == null) return false;
        return tap['screen'] == screenName && (tapTime.difference(visitTime).inSeconds.abs() <= 30);
      }).toList();

      final relatedSwipes = allSwipeEvents.where((swipe) {
        final swipeTime = DateTime.tryParse(swipe['timestamp']);
        if (swipeTime == null || visitTime == null) return false;
        return (swipeTime.difference(visitTime).inSeconds.abs() <= 30);
      }).toList();

      return {
        ...visit,
        'tap_events': relatedTaps,
        'swipe_events': relatedSwipes,
      };
    }).toList();

    // Assemble session log JSON
    final sessionData = {
      'session': {
        'start': _sessionTracker.startTimestamp,
        'end': _sessionTracker.endTimestamp,
        'duration_seconds': sessionDuration,
      },
      'device': deviceInfo,
      'location': location != null
          ? {'latitude': location.latitude, 'longitude': location.longitude}
          : 'Location unavailable',
      'tap_durations_ms': _tapTracker.getTapDurations(),
      'tap_events': dedupedTapEvents,
      'swipe_events': allSwipeEvents,
      'screens_visited': enrichedScreenVisits,
      'screen_durations': _screenDurations,
      'screen_recording_detected': _screenRecordingDetected,

      'session_input': {
        'within_bank_transfer_amount': _inputTracker.getTransactionAmount(),
        'fd_broken': _inputTracker.isFDBroken,
        'loan_taken': _inputTracker.isLoanTaken,
        'time_from_login_to_fd': _inputTracker.timeFromLoginToFD?.inSeconds,
        'time_from_login_to_loan': _inputTracker.timeFromLoginToLoan?.inSeconds,
        'time_from_login_to_transaction': _inputTracker.timeFromLoginToTransactionStart?.inSeconds,
        'time_for_transaction': _inputTracker.timeToCompleteTransaction?.inSeconds,
      },
    };

    await _exportManager.exportToJson(sessionData, 'session_log');
    print("📁 Session exported");
  }
}

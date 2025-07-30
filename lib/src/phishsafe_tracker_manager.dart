import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'network/api_service.dart';

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

// Behavior Management
import 'behaviour.dart';
import 'model.dart';


class PhishSafeTrackerManager {
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
  final BehaviourManager _behaviourManager = BehaviourManager();

  final Map<String, int> _screenDurations = {};
  Timer? _screenRecordingTimer;
  bool _screenRecordingDetected = false;
  BuildContext? _context;

  String? _currentScreen;
  DateTime? _screenEnterTime;

  void setContext(BuildContext context) {
    _context = context;
    _behaviourManager.setContext(context);
  }

  void startSession() {
    _tapTracker.reset();
    _swipeTracker.reset();
    _navLogger.reset();
    _sessionTracker.startSession();
    _inputTracker.reset();
    _inputTracker.markLogin();
    _screenRecordingDetected = false;
    _screenDurations.clear();
    _currentScreen = null;
    _screenEnterTime = null;

    if (_context != null) {
      _behaviourManager.startSession(_context!);
    }

    print("✅ PhishSafe session started");
    ApiService.sendSessionStart(DateTime.now());

    _screenRecordingTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      final isRecording = await ScreenRecordingDetector().isScreenRecording();
      if (isRecording && !_screenRecordingDetected) {
        _screenRecordingDetected = true;
        print("🚨 Screen recording detected");
        ApiService.sendScreenRecording(true);
        _behaviourManager.detectBehavior(1); // Screen recording behavior

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

  void setLogoutCallback(VoidCallback callback) {
    _behaviourManager.setLogoutCallback(callback);
  }

  void onScreenVisited(String screen) {
    final now = DateTime.now();

    if (_currentScreen != null && _screenEnterTime != null) {
      final duration = now.difference(_screenEnterTime!).inSeconds;
      _screenDurations[_currentScreen!] = (_screenDurations[_currentScreen!] ?? 0) + duration;
      print("⏱ Screen duration recorded: $_currentScreen → $duration seconds");
      ApiService.sendScreenDurations(_screenDurations);
    }

    _currentScreen = screen;
    _screenEnterTime = now;

    _navLogger.logVisit(screen);
    _behaviourManager.trackScreenVisit(screen);
    ApiService.sendScreenVisit(screen);
  }

  void recordScreenDuration(String screen, int seconds) {
    _screenDurations[screen] = (_screenDurations[screen] ?? 0) + seconds;
    print("📺 Screen duration recorded manually: $screen → $seconds seconds");
    ApiService.sendScreenDurations(_screenDurations);
  }

  void onTap(String screen) {
    _tapTracker.recordTap(
      screenName: screen,
      tapPosition: Offset.zero,
      tapZone: 'unknown',
    );
    ApiService.sendTap(screen);
  }

  void recordTapPosition({
    required String screenName,
    required Offset tapPosition,
    required String tapZone,
  }) {
    _tapTracker.recordTap(
      screenName: screenName,
      tapPosition: tapPosition,
      tapZone: tapZone,
    );
    print("📌 Tap recorded at $tapPosition on $screenName in zone $tapZone");
    ApiService.sendTapEvent(
      screenName: screenName,
      position: tapPosition,
      tapZone: tapZone,
    );

    _tapTracker.recordTapDuration(screenName: screenName, durationMs: 100);

    // Detect inactive area taps
    if (tapZone == 'inactive') {
      _behaviourManager.trackInactiveAreaTap();
    }
  }

  void recordTapDuration({
    required String screenName,
    required int durationMs,
  }) {
    _tapTracker.recordTapDuration(screenName: screenName, durationMs: durationMs);

    // Detect abnormal tap durations
    if (durationMs < 100) {
      _behaviourManager.detectBehavior(6, durationMs); // Very fast tapping
    } else if (durationMs > 2000) {
      _behaviourManager.detectBehavior(7, durationMs); // Very slow tapping
    }
  }

  void onSwipeStart(double pos) => _swipeTracker.startSwipe(pos);

  void onSwipeEnd(double pos) {
    _swipeTracker.endSwipe(pos);
    final swipe = _swipeTracker.getLastSwipe();
    if (swipe != null) {
      ApiService.sendSwipe(swipe);

      // Detect abnormal swipe speeds
      final speed = swipe['speed'];
      if (speed != null && speed > 5.0) {
        _behaviourManager.detectBehavior(8, swipe['speed']);
      }
    }
  }

  void recordSwipeMetrics({
    required String screenName,
    required int durationMs,
    required double distance,
    required double speed,
  }) {
    _swipeTracker.recordSwipeMetrics(
      screen: screenName,
      durationMs: durationMs,
      distance: distance,
      speed: speed,
    );
    print("🚀 Swipe recorded → Duration: ${durationMs}ms, Distance: ${distance.toStringAsFixed(1)}px, Speed: ${speed.toStringAsFixed(3)} px/ms");

    if (speed > 5.0) {
      _behaviourManager.detectBehavior(8, speed); // Very fast swipe
    }
  }

  void recordWithinBankTransferAmount(String amount) {
    _inputTracker.setTransactionAmount(amount);
    print("💰 Within-bank transfer amount tracked: $amount");
    ApiService.sendTransactionAmount(amount);

    // Trigger behavior check for large transactions
    final parsedAmount = double.tryParse(amount.replaceAll(',', ''));
    if (parsedAmount != null && parsedAmount >= 50000) {
      _behaviourManager.trackLargeTransaction(parsedAmount);
    }
  }

  void recordFDBroken() {
    _inputTracker.markFDBroken();
    print("🧨 FD broken marked");
    _behaviourManager.trackFDBroken();
    ApiService.sendFDBroken();
  }

  void recordLoanTaken() {
    _inputTracker.markLoanTaken();
    print("📋 Loan application recorded");
    _behaviourManager.trackLoanViewed();
    ApiService.sendLoanTaken();
  }

  void markTransactionStart() {
    _inputTracker.markTransactionStart();
    print("🏁 Transaction started");
  }

  void markTransactionEnd() {
    _inputTracker.markTransactionEnd();
    print("✅ Transaction ended");
  }

  void trackOtpSkip() {
    _behaviourManager.trackOtpSkip();
    print("⏭ OTP skip tracked");
  }

  void trackFailedPinAttempt() {
    _behaviourManager.detectBehavior(21); // Failed PIN attempt
    print("❌ Failed PIN attempt tracked");
  }

  Future<void> endSessionAndExport() async {
    _sessionTracker.endSession();
    _screenRecordingTimer?.cancel();
    _screenRecordingTimer = null;
    _behaviourManager.endSession();

    // Final screen duration recording
    if (_currentScreen != null && _screenEnterTime != null) {
      final now = DateTime.now();
      final duration = now.difference(_screenEnterTime!).inSeconds;
      _screenDurations[_currentScreen!] = (_screenDurations[_currentScreen!] ?? 0) + duration;
      print("⏱ Final screen duration recorded: $_currentScreen → $duration seconds");
    }

    final Position? location = await _locationTracker.getCurrentLocation();
    final deviceInfo = await _deviceLogger.getDeviceInfo();
    final sessionDuration = _sessionTracker.sessionDuration?.inSeconds ?? 0;

    final allTapEvents = _tapTracker.getTapEvents();
    final allSwipeEvents = _swipeTracker.getSwipeEvents();
    final screenVisits = _navLogger.logs;

    final filteredTapEvents = allTapEvents.where((tap) {
      final pos = tap['position'];
      final zone = tap['zone'];
      if (pos == null || zone == null) return false;
      if (pos['dx'] == 0.0 && pos['dy'] == 0.0) return false;
      if (zone == 'unknown') return false;
      return true;
    }).toList();

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
        return diff <= 300;
      });
      if (!duplicateFound) {
        dedupedTapEvents.add(tap);
      }
    }

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

    final sessionData = {
      'session': {
        'start': _sessionTracker.startTimestamp,
        'end': _sessionTracker.endTimestamp,
        'duration_seconds': sessionDuration,
        'penalties_applied': _behaviourManager.getAppliedPenalties(),
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
      'behavior_analysis': _behaviourManager.getBehaviorLogs(),
    };

    // 🧠 Calculate final trust score
    final sessionFiles = await BaselineBuilder().getSessionFiles();
    final sessionCount = sessionFiles.length;
    final double mlModelScore = await TrustModel().predict(sessionData);
    final double finalTrustScore = _behaviourManager.calculateFinalTrustScore(
      sessionCount: sessionCount,
      mlModelScore: mlModelScore,
      currentSession: sessionData,
    );

    print("🎯 Final Trust Score: ${finalTrustScore.toStringAsFixed(2)}");
    sessionData['session'] ??= {};  // Step 2A: ensure 'session' is a non-null map
    (sessionData['session'] as Map)['trust_score'] = finalTrustScore.toStringAsFixed(2);  // Step 2B: safely assign trust score


    if (location != null) {
      ApiService.sendLocation({
        'latitude': location.latitude,
        'longitude': location.longitude,
      });
    }

    ApiService.sendDeviceInfo(deviceInfo);
    ApiService.sendTapDurations(_tapTracker.getTapDurations());
    ApiService.sendSwipeMetrics(allSwipeEvents);
    ApiService.sendInputTiming({
      'time_from_login_to_fd': _inputTracker.timeFromLoginToFD?.inSeconds,
      'time_from_login_to_loan': _inputTracker.timeFromLoginToLoan?.inSeconds,
      'time_from_login_to_transaction': _inputTracker.timeFromLoginToTransactionStart?.inSeconds,
      'time_for_transaction': _inputTracker.timeToCompleteTransaction?.inSeconds,
    });

    ApiService.sendSessionEnd(DateTime.now());
    await _exportManager.exportToJson(sessionData, 'session_log');
    ApiService.sendExportedSession(sessionData);
    print("📁 Session exported");
  }
}
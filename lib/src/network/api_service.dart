import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class ApiService {
  static const baseUrl = 'http://172.20.10.3:5018/'; // Update with your backend IP

  static Future<void> _post(String endpoint, Map<String, dynamic> body) async {
    final fullUrl = '$baseUrl$endpoint';

    try {
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final msg = jsonDecode(response.body)['message'] ?? 'OK';
        print("✅ [${endpoint}] ${DateTime.now().toIso8601String()} → $msg");
      } else {
        print("❌ [$endpoint] ${response.statusCode} → ${response.body}");
      }
    } catch (e) {
      print("❗ [$endpoint] Exception → $e");
    }
  }

  // Tap Events
  static Future<void> sendTap(String screen) => _post('/tap_event', {
    'event': 'tap',
    'screen': screen,
    'timestamp': DateTime.now().toIso8601String(),
  });

  static Future<void> sendTapEvent({
    required String screenName,
    required Offset position,
    required String tapZone,
  }) => _post('/tap_event', {
    'event': 'tap',
    'screen': screenName,
    'position': {'x': position.dx, 'y': position.dy},
    'tap_zone': tapZone,
    'timestamp': DateTime.now().toIso8601String(),
  });

  // Swipe Events
  static Future<void> sendSwipe(Map<String, dynamic> swipeData) =>
      _post('/swipe_event', swipeData);

  static Future<void> sendSwipeMetrics(List<Map<String, dynamic>> metrics) =>
      _post('/swipe_metrics', {'swipe_metrics': metrics});

  // Screen Events
  static Future<void> sendScreenVisit(String screen) => _post('/screen_visit', {
    'screen': screen,
    'timestamp': DateTime.now().toIso8601String(),
  });

  static Future<void> sendScreenDurations(Map<String, int> durations) =>
      _post('/screen_duration', {'durations': durations});

  // Session Events
  static Future<void> sendSessionStart(DateTime start) =>
      _post('/session_start', {'start': start.toIso8601String()});

  static Future<void> sendSessionEnd(DateTime end) =>
      _post('/session_end', {'end': end.toIso8601String()});

  static Future<void> sendExportedSession(Map<String, dynamic> sessionData) =>
      _post('/export_session', sessionData);

  // Device & Environment
  static Future<void> sendScreenRecording(bool isRecording) => _post('/screen_recording', {
    'recording': isRecording,
    'timestamp': DateTime.now().toIso8601String(),
  });

  static Future<void> sendDeviceInfo(Map<String, dynamic> info) =>
      _post('/device_info', info);

  static Future<void> sendLocation(Map<String, dynamic> loc) => _post(
    '/location_info',
    {...loc, 'timestamp': DateTime.now().toIso8601String()},
  );

  // Analytics
  static Future<void> sendTapDurations(List<double> durations) =>
      _post('/tap_durations', {'durations_ms': durations});

  // Transaction Events
  static Future<void> sendTransactionAmount(String amount) => _post('/transaction_amount', {
    'amount': amount,
    'timestamp': DateTime.now().toIso8601String(),
  });

  static Future<void> sendFDBroken() => _post('/fd_broken', {
    'event': 'FD Broken',
    'timestamp': DateTime.now().toIso8601String(),
  });

  static Future<void> sendLoanTaken() => _post('/loan_taken', {
    'event': 'Loan Taken',
    'timestamp': DateTime.now().toIso8601String(),
  });

  static Future<void> sendInputTiming(Map<String, dynamic> timings) =>
      _post('/input_timing', timings);
}
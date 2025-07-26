import 'package:flutter/material.dart';

class TapTracker {
  final List<int> _tapDurations = [];
  DateTime? _lastTap;

  final List<Map<String, dynamic>> _tapEvents = [];

  /// Records a tap event.
  /// [screenName] - the name of the screen where the tap occurred.
  /// [tapPosition] - the global Offset position of the tap.
  /// [tapZone] - a zone name defining the tap location within the screen (required).
  void recordTap({
    required String screenName,
    required Offset tapPosition,
    required String tapZone,
  }) {
    final now = DateTime.now();

    print("🧠 Recording tap on $screenName at $now @ $tapPosition in zone $tapZone");

    // Calculate and record duration since last tap
    if (_lastTap != null) {
      final diff = now.difference(_lastTap!).inMilliseconds;
      _tapDurations.add(diff);
    }

    // Create and add the tap event with position and zone
    final event = {
      'timestamp': now.toIso8601String(),
      'screen': screenName,
      'position': {'dx': tapPosition.dx, 'dy': tapPosition.dy},
      'zone': tapZone,
    };

    _tapEvents.add(event);

    _lastTap = now;
  }

  List<int> getTapDurations() => List.unmodifiable(_tapDurations);

  List<Map<String, dynamic>> getTapEvents() => List.unmodifiable(_tapEvents);

  void reset() {
    _lastTap = null;
    _tapDurations.clear();
    _tapEvents.clear();
  }
}

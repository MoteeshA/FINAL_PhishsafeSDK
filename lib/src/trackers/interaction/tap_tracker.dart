import 'package:flutter/material.dart';

class TapTracker {
  final List<int> _tapDurations = [];
  DateTime? _lastTap;

  final List<Map<String, dynamic>> _tapEvents = [];

  // New: Store tap durations per screen (in milliseconds)
  final Map<String, int> _tapDurationsPerScreen = {};

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

  /// Records tap duration for a specific screen (in milliseconds).
  void recordTapDuration({
    required String screenName,
    required int durationMs,
  }) {
    _tapDurationsPerScreen[screenName] = (_tapDurationsPerScreen[screenName] ?? 0) + durationMs;
    print("🕒 Tap duration recorded: $durationMs ms on $screenName");
  }

  /// Returns a list of tap durations converted to double (in milliseconds).
  List<double> getTapDurations() =>
      _tapDurations.map((e) => e.toDouble()).toList(growable: false);

  /// Returns the tap durations per screen (milliseconds).
  Map<String, int> getTapDurationsPerScreen() => Map.unmodifiable(_tapDurationsPerScreen);

  /// Returns the list of tap events (timestamp, screen, position, zone).
  List<Map<String, dynamic>> getTapEvents() =>
      List.unmodifiable(_tapEvents);

  /// Resets the tracker (clears all data).
  void reset() {
    _lastTap = null;
    _tapDurations.clear();
    _tapEvents.clear();
    _tapDurationsPerScreen.clear();
  }
}

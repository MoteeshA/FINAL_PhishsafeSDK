import 'package:flutter/material.dart';
import 'package:phishsafe_sdk/src/phishsafe_tracker_manager.dart';
import 'dart:math';

class GestureWrapper extends StatefulWidget {
  final Widget child;
  final String screenName;

  const GestureWrapper({
    Key? key,
    required this.child,
    required this.screenName,
  }) : super(key: key);

  @override
  State<GestureWrapper> createState() => _GestureWrapperState();
}

class _GestureWrapperState extends State<GestureWrapper> {
  Offset? _startPosition;
  DateTime? _tapStartTime;
  DateTime? _swipeStartTime;

  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _key,
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _startPosition = event.position;
        _tapStartTime = DateTime.now();
        _swipeStartTime = _tapStartTime;

        final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final localPosition = renderBox.globalToLocal(event.position);
          final size = renderBox.size;

          final tapZone = _getTapZone(localPosition, size);

          PhishSafeTrackerManager().recordTapPosition(
            screenName: widget.screenName,
            tapPosition: event.position,
            tapZone: tapZone,
          );

          print("👆 TAP on ${widget.screenName} at $localPosition zone $tapZone");
        } else {
          PhishSafeTrackerManager().recordTapPosition(
            screenName: widget.screenName,
            tapPosition: event.position,
            tapZone: 'unknown',
          );
          print("👆 TAP on ${widget.screenName} at unknown zone");
        }
      },
      onPointerUp: (event) {
        final endPosition = event.position;
        final now = DateTime.now();

        // 🔹 Tap Duration
        if (_tapStartTime != null) {
          final tapDuration = now.difference(_tapStartTime!).inMilliseconds;
          PhishSafeTrackerManager().recordTapDuration(
            screenName: widget.screenName,
            durationMs: tapDuration,
          );
          print("🕒 TAP duration on ${widget.screenName}: ${tapDuration}ms");
        }

        // 🔹 Swipe Duration, Distance, Speed
        if (_startPosition != null && _swipeStartTime != null) {
          final swipeDurationMs = now.difference(_swipeStartTime!).inMilliseconds;
          final dx = endPosition.dx - _startPosition!.dx;
          final dy = endPosition.dy - _startPosition!.dy;
          final distance = sqrt(dx * dx + dy * dy);

          // Only consider as swipe if moved > 20px
          if (distance > 20) {
            final speed = distance / swipeDurationMs;

            PhishSafeTrackerManager().recordSwipeMetrics(
              screenName: widget.screenName,
              durationMs: swipeDurationMs,
              distance: distance,
              speed: speed,
            );

            print("👉 SWIPE from ${_startPosition} to $endPosition");
            print("🕒 Swipe Duration: ${swipeDurationMs}ms, 📏 Distance: ${distance.toStringAsFixed(2)} px, 🚀 Speed: ${speed.toStringAsFixed(3)} px/ms");
          }
        }

        // Reset
        _startPosition = null;
        _tapStartTime = null;
        _swipeStartTime = null;
      },
      child: widget.child,
    );
  }

  String _getTapZone(Offset localPosition, Size size) {
    final zoneWidth = size.width / 3;
    final zoneHeight = size.height / 3;

    int col = (localPosition.dx / zoneWidth).floor().clamp(0, 2);
    int row = (localPosition.dy / zoneHeight).floor().clamp(0, 2);

    const zoneMap = {
      0: {0: 'top_left', 1: 'top_center', 2: 'top_right'},
      1: {0: 'middle_left', 1: 'center', 2: 'middle_right'},
      2: {0: 'bottom_left', 1: 'bottom_center', 2: 'bottom_right'},
    };

    return zoneMap[row]?[col] ?? 'unknown';
  }
}

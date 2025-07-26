import 'package:flutter/material.dart';
import 'package:phishsafe_sdk/src/phishsafe_tracker_manager.dart';

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
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _key,
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _startPosition = event.position;

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
          // Fallback only if renderBox is null (rare)
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
        if (_startPosition != null) {
          final dy = (endPosition.dy - _startPosition!.dy).abs();
          final dx = (endPosition.dx - _startPosition!.dx).abs();

          // Detect swipe only if significant movement
          if (dy > 20 || dx > 20) {
            PhishSafeTrackerManager().onSwipeStart(_startPosition!.dy);
            PhishSafeTrackerManager().onSwipeEnd(endPosition.dy);
            print("👉 SWIPE from ${_startPosition!.dy} to ${endPosition.dy}");
          }

          _startPosition = null;
        }
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

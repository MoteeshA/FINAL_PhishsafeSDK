import 'package:flutter/material.dart';
import 'package:phishsafe_sdk/phishsafe_sdk.dart'; // your SDK

class RouteAwareWrapper extends StatefulWidget {
  final Widget child;
  final String screenName;
  final RouteObserver<PageRoute> observer;

  const RouteAwareWrapper({
    required this.child,
    required this.screenName,
    required this.observer,
    Key? key,
  }) : super(key: key);

  @override
  _RouteAwareWrapperState createState() => _RouteAwareWrapperState();
}

class _RouteAwareWrapperState extends State<RouteAwareWrapper> with RouteAware {
  DateTime? _entryTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.observer.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    widget.observer.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    _entryTime = DateTime.now();  // ✅ Record entry time
    PhishSafeSDK.onScreenVisit(widget.screenName);
    print("📥 Entered screen: ${widget.screenName} at $_entryTime");
  }

  @override
  void didPop() {
    final exitTime = DateTime.now();
    final duration = _entryTime != null
        ? exitTime.difference(_entryTime!)
        : Duration.zero;

    PhishSafeSDK.onScreenExit(widget.screenName);
    PhishSafeSDK.logScreenDuration(widget.screenName, duration.inSeconds); // ✅ ACTUAL TRACKING
    print("📤 Exited screen: ${widget.screenName} at $exitTime");
    print("🕒 Time spent on ${widget.screenName}: ${duration.inSeconds} seconds");
  }


  @override
  Widget build(BuildContext context) => widget.child;
}

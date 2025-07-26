class SessionTracker {
  DateTime? _startTime;
  DateTime? _endTime;

  void startSession() {
    _startTime = DateTime.now();
    _endTime = null;
  }

  void endSession() {
    _endTime = DateTime.now();
  }

  Duration? get sessionDuration {
    if (_startTime != null && _endTime != null) {
      return _endTime!.difference(_startTime!);
    }
    return null;
  }

  String? get startTimestamp => _startTime?.toIso8601String();
  String? get endTimestamp => _endTime?.toIso8601String();

  void reset() {
    _startTime = null;
    _endTime = null;
  }
}

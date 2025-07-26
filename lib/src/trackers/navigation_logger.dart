class NavigationLogger {
  final List<Map<String, dynamic>> _screenLogs = [];

  /// Log the visit to a screen with timestamp
  void logVisit(String screenName) {
    _screenLogs.add({
      'screen': screenName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Get all logged screens
  List<Map<String, dynamic>> get logs => List.unmodifiable(_screenLogs);

  /// Reset for new session
  void reset() {
    _screenLogs.clear();
  }
}

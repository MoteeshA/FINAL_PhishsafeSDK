import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart'; // for temp file in predict()

class TrustModel {
  late Interpreter _interpreter;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model_light.tflite');
      _isLoaded = true;
      print('✅ TFLite model loaded!');
    } catch (e) {
      print('❌ Failed to load model: $e');
    }
  }

  Future<double> runInference(List<double> features) async {
    if (!_isLoaded) throw Exception("Model not loaded");

    final input = [features]; // shape [1, 19]
    final output = List.filled(1 * 1, 0.0).reshape([1, 1]);

    _interpreter.run(input, output);
    print('🎯 Model output: $output');
    return output[0][0];
  }

  void close() {
    _interpreter.close();
    print('🧹 Interpreter closed.');
  }

  /// ✅ Use this to directly run inference on a session Map
  Future<double> predict(Map<String, dynamic> sessionData) async {
    // Save session map to temporary file
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/session_temp.json');
    await tempFile.writeAsString(jsonEncode(sessionData));

    // Load model if not already
    if (!_isLoaded) await loadModel();

    // Extract features and run
    final features = await extractFeaturesFromSession(tempFile.path);
    return await runInference(features);
  }

  /// Extracts all 19 features from session JSON
  Future<List<double>> extractFeaturesFromSession(String sessionPath) async {
    final file = File(sessionPath);
    final session = jsonDecode(await file.readAsString());

    // 1. Session Duration
    double sessionDuration = (session['session']['duration_seconds'] ?? 0).toDouble();

    // 2. Tap durations
    List<dynamic> taps = session['tap_durations_ms'] ?? [];
    List<double> tapDurations = taps.map((e) => (e as num).toDouble()).toList();
    double meanTap = _mean(tapDurations);
    double stdTap = _std(tapDurations);

    // 3. Tap frequency
    double tapFreq = tapDurations.length / max(sessionDuration, 1);

    // 4. Swipe speeds/distances
    List<double> swipeSpeeds = [];
    List<double> swipeDistances = [];

    var swipes = session['swipe_events'] ?? [];
    for (var s in swipes) {
      swipeSpeeds.add((s['speed_px_per_ms'] ?? 0).toDouble());
      swipeDistances.add((s['distance_px'] ?? 0).toDouble());
    }

    double meanSwipeSpeed = _mean(swipeSpeeds);
    double stdSwipeSpeed = _std(swipeSpeeds);
    double meanSwipeDist = _mean(swipeDistances);
    double stdSwipeDist = _std(swipeDistances);

    // 5. Tap zones
    double totalX = 0, totalY = 0;
    int count = 0;
    var tapEvents = session['tap_events'] ?? [];
    for (var tap in tapEvents) {
      totalX += (tap['position']['dx'] ?? 0).toDouble();
      totalY += (tap['position']['dy'] ?? 0).toDouble();
      count++;
    }
    double tapZoneX = count > 0 ? totalX / count : 0;
    double tapZoneY = count > 0 ? totalY / count : 0;

    // 6. Swipe zones
    double swipeZoneX = 0, swipeZoneY = 0;
    count = 0;
    for (var screen in (session['screens_visited'] ?? [])) {
      for (var swipe in (screen['swipe_events'] ?? [])) {
        swipeZoneX += (swipe['distance_px'] ?? 0).toDouble();
        swipeZoneY += (swipe['speed_px_per_ms'] ?? 0).toDouble();
        count++;
      }
    }
    swipeZoneX = count > 0 ? swipeZoneX / count : 0;
    swipeZoneY = count > 0 ? swipeZoneY / count : 0;

    // 7. Screen durations
    Map<String, dynamic> screenDurations = session['screen_durations'] ?? {};
    List<double> screenDurVals = screenDurations.values.map((e) => (e as num).toDouble()).toList();
    double meanScreen = _mean(screenDurVals);
    double stdScreen = _std(screenDurVals);

    // 8. Behavior flags
    var input = session['session_input'] ?? {};
    bool fdBroken = input['fd_broken'] ?? false;
    bool loanTaken = input['loan_taken'] ?? false;
    double loginToFD = (input['time_from_login_to_fd'] ?? 0).toDouble();
    double loginToLoan = (input['time_from_login_to_loan'] ?? 0).toDouble();
    double loginToTxn = (input['time_from_login_to_transaction'] ?? 0).toDouble();

    return [
      sessionDuration,        // 0
      meanTap,                // 1
      stdTap,                 // 2
      tapFreq,                // 3
      meanSwipeSpeed,         // 4
      stdSwipeSpeed,          // 5
      meanSwipeDist,          // 6
      stdSwipeDist,           // 7
      tapZoneX,               // 8
      tapZoneY,               // 9
      swipeZoneX,             // 10
      swipeZoneY,             // 11
      meanScreen,             // 12
      stdScreen,              // 13
      fdBroken ? 1.0 : 0.0,   // 14
      loanTaken ? 1.0 : 0.0,  // 15
      loginToFD,              // 16
      loginToLoan,            // 17
      loginToTxn              // 18
    ];
  }

  // Helper: Mean
  double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // Helper: Standard Deviation (fixed)
  double _std(List<double> values) {
    if (values.length <= 1) return 0;
    double m = _mean(values);
    double sumSquaredDiff = values
        .map((x) => pow(x - m, 2).toDouble())
        .reduce((a, b) => a + b);
    return sqrt(sumSquaredDiff / (values.length - 1));
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

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

  final List<double> _means = [
    44.55394807692308, 517.4076923076923, 275.02564102564105, 2.050989743589744,
    231.0076923076923, 108.54102564102564, 420.8897435897436, 103.22923076923077,
    0.4811384615384615, 0.7235333333333332, 299.53589743589746, 45.984615384615385,
    5.199487179487179, 3.4185641025641023, 0.22615384615384615, 0.24358974358974358,
    5.425641025641025, 8.318461538461538, 6.051282051282051
  ];

  final List<double> _scales = [
    38.71920315521891, 285.9501626903347, 284.39112962178975, 1.3649466392109674,
    140.59527359872443, 90.65562427652266, 260.03406561423284, 97.7172230473892,
    0.22956360504198597, 0.1920813428620963, 178.71014028917448, 20.296558200451885,
    2.3860073846799905, 2.056288195006364, 0.4182394409139344, 0.42917735103373923,
    2.7027376748811097, 3.3612042865360026, 2.907783513085287
  ];

  List<double> normalize(List<double> features) {
    return List.generate(features.length, (i) {
      final scale = _scales[i];
      return scale != 0 ? (features[i] - _means[i]) / scale : 0.0;
    });
  }

  Future<double> runInference(List<double> features, {Map<String, dynamic>? sessionData}) async {
    if (!_isLoaded) throw Exception("Model not loaded");

    final input = [normalize(features)];
    final output = List.filled(1 * 1, 0.0).reshape([1, 1]);

    _interpreter.run(input, output);
    double raw = output[0][0];//because may be 0 or 1

    double confidence = _mapConfidence(raw, sessionData);
    print('🎯 Mapped confidence score: $confidence');
    return confidence;
  }

  double _mapConfidence(double output, Map<String, dynamic>? sessionData) {
    if (output == 1.0) {
      return 0.8 + Random().nextDouble() * 0.2; // suspicious → [0.8 - 1.0]
    }

    double score = 0.7; // base score for normal output

    try {
      final session = sessionData ?? {};
      final duration = (session['session']?['duration_seconds'] ?? 0).toDouble();
      final taps = (session['tap_durations_ms'] ?? []) as List;
      final screens = (session['screens_visited'] ?? []) as List;

      if (duration >= 30) score += 0.1;
      if (taps.length >= 5) score += 0.05;
      if (screens.length >= 3) score += 0.05;

      score = score.clamp(0.6, 0.95); // realistic range
    } catch (e) {
      print("⚠️ Error mapping confidence: $e");
    }

    return score;
  }

  void close() {
    _interpreter.close();
    print('🧹 Interpreter closed.');
  }

  Future<double> predict(Map<String, dynamic> sessionData) async {
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/session_temp.json');
    await tempFile.writeAsString(jsonEncode(sessionData));

    if (!_isLoaded) await loadModel();

    final features = await extractFeaturesFromSession(tempFile.path);
    return await runInference(features, sessionData: sessionData);
  }

  Future<List<double>> extractFeaturesFromSession(String sessionPath) async {
    final file = File(sessionPath);
    final session = jsonDecode(await file.readAsString());

    double sessionDuration = (session['session']['duration_seconds'] ?? 0).toDouble();

    List<dynamic> taps = session['tap_durations_ms'] ?? [];
    List<double> tapDurations = taps.map((e) => (e as num).toDouble()).toList();
    double meanTap = _mean(tapDurations);
    double stdTap = _std(tapDurations);
    double tapFreq = tapDurations.length / max(sessionDuration, 1);

    List<double> swipeSpeeds = [], swipeDistances = [];
    var swipes = session['swipe_events'] ?? [];
    for (var s in swipes) {
      swipeSpeeds.add((s['speed_px_per_ms'] ?? 0).toDouble());
      swipeDistances.add((s['distance_px'] ?? 0).toDouble());
    }

    double meanSwipeSpeed = _mean(swipeSpeeds);
    double stdSwipeSpeed = _std(swipeSpeeds);
    double meanSwipeDist = _mean(swipeDistances);
    double stdSwipeDist = _std(swipeDistances);

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

    Map<String, dynamic> screenDurations = session['screen_durations'] ?? {};
    List<double> screenDurVals = screenDurations.values.map((e) => (e as num).toDouble()).toList();
    double meanScreen = _mean(screenDurVals);
    double stdScreen = _std(screenDurVals);

    var input = session['session_input'] ?? {};
    bool fdBroken = input['fd_broken'] ?? false;
    bool loanTaken = input['loan_taken'] ?? false;
    double loginToFD = (input['time_from_login_to_fd'] ?? 0).toDouble();
    double loginToLoan = (input['time_from_login_to_loan'] ?? 0).toDouble();
    double loginToTxn = (input['time_from_login_to_transaction'] ?? 0).toDouble();

    return [
      sessionDuration, meanTap, stdTap, tapFreq,
      meanSwipeSpeed, stdSwipeSpeed, meanSwipeDist, stdSwipeDist,
      tapZoneX, tapZoneY, swipeZoneX, swipeZoneY,
      meanScreen, stdScreen,
      fdBroken ? 1.0 : 0.0, loanTaken ? 1.0 : 0.0,
      loginToFD, loginToLoan, loginToTxn
    ];
  }

  double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _std(List<double> values) {
    if (values.length <= 1) return 0;
    double m = _mean(values);
    double sumSquaredDiff = values.map((x) => pow(x - m, 2).toDouble()).reduce((a, b) => a + b);
    return sqrt(sumSquaredDiff / (values.length - 1));
  }
}

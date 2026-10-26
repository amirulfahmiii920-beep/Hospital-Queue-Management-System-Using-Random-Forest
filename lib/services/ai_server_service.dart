import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// Talks to the Python AI server (qhealth-ai-server on Render).
// Both calls return null when the server cannot give an estimate,
// so the caller can fall back to its default.

const String screeningPredictUrl =
    'https://qhealth-ai-server.onrender.com/predict_ewt';

// The app sends the hour as hour + minute / 100 (10:30 -> 10.3).
// The server only uses the whole hour.
double _exactHour(DateTime now) => now.hour + (now.minute / 100.0);

int? _readEstimate(http.Response response) {
  if (response.statusCode != 200) return null;
  final responseData = jsonDecode(response.body);
  if (responseData['success'] == true) {
    return responseData['estimated_time_mins'];
  }
  return null;
}

// SCREENING QUEUE ESTIMATE
// Long timeout because the free Render server sleeps and wakes slowly.
Future<int?> fetchScreeningEstimate() async {
  try {
    DateTime now = DateTime.now();

    final aiResponse = await http
        .post(
          Uri.parse(screeningPredictUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "Entry_Hour": _exactHour(now),
            "Entry_Day": now.weekday % 7,
            "Patient Type": 1,
            "Financial Class": 0,
          }),
        )
        .timeout(const Duration(seconds: 60));

    return _readEstimate(aiResponse);
  } catch (aiError) {
    debugPrint("AI Server cannot be connected : $aiError");
    return null;
  }
}

// DOCTOR QUEUE ESTIMATE (URL comes from AI_SERVER_URL in .env)
Future<int?> fetchConsultEstimate({required int queueLength}) async {
  final String aiConsultUrl = dotenv.env['AI_SERVER_URL'] ?? '';
  try {
    DateTime now = DateTime.now();

    final aiResponse = await http
        .post(
          Uri.parse(aiConsultUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "Entry_Hour": _exactHour(now),
            "Queue_Length": queueLength, // Send queue length to AI
            "Department": "General",
          }),
        )
        .timeout(const Duration(seconds: 5));

    return _readEstimate(aiResponse);
  } catch (aiError) {
    debugPrint("AI Consult Server error: $aiError");
    return null;
  }
}

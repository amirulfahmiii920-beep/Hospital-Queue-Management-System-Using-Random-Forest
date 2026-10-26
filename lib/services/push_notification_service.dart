import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// Function to send push notification to a specific patient
Future<void> sendPushNotification(
  String targetPatientId,
  String title,
  String message,
) async {
  String oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  String oneSignalRestApiKey = dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

  var url = Uri.parse('https://onesignal.com/api/v1/notifications');

  var requestBody = jsonEncode({
    "app_id": oneSignalAppId,
    "target_channel": "push",
    "include_aliases": {
      "external_id": [targetPatientId], // Target patient by their external ID
    },
    "headings": {"en": title},
    "contents": {"en": message},
  });

  try {
    var response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": "Basic $oneSignalRestApiKey",
        "accept": "application/json",
      },
      body: requestBody,
    );

    if (response.statusCode == 200) {
      debugPrint(
        "Successfully sent push notification to patient: $targetPatientId",
      );
    } else {
      debugPrint("Failed to send notification: ${response.body}");
    }
  } catch (e) {
    debugPrint("Notification system error: $e");
  }
}

// FUNCTION: SCHEDULE PUSH NOTIFICATION
Future<void> sendScheduledPushNotification(
  String targetPatientId,
  String title,
  String message,
  int delayInSeconds,
) async {
  String oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  String oneSignalRestApiKey = dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

  var url = Uri.parse('https://onesignal.com/api/v1/notifications');

  // Calculate exact time to trigger notification (Current Time + Wait Time)
  DateTime sendTime = DateTime.now().toUtc().add(
    Duration(seconds: delayInSeconds),
  );
  String y = sendTime.year.toString();
  String m = sendTime.month.toString().padLeft(2, '0');
  String d = sendTime.day.toString().padLeft(2, '0');
  String h = sendTime.hour.toString().padLeft(2, '0');
  String min = sendTime.minute.toString().padLeft(2, '0');
  String s = sendTime.second.toString().padLeft(2, '0');

  // Format: "YYYY-MM-DD HH:MM:SS GMT+0000"
  String formattedTime = "$y-$m-$d $h:$min:$s GMT+0000";

  var requestBody = jsonEncode({
    "app_id": oneSignalAppId,
    "target_channel": "push",
    "include_aliases": {
      "external_id": [targetPatientId],
    },
    "headings": {"en": title},
    "contents": {"en": message},
    "send_after": formattedTime, // This tells OneSignal exactly WHEN to send it
  });

  try {
    await http.post(
      url,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": "Basic $oneSignalRestApiKey",
      },
      body: requestBody,
    );
  } catch (e) {
    debugPrint("Scheduling error: $e");
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Queue numbers are only given out between 8:00 AM and 4:30 PM
const int clinicOpensAtMinutes = 8 * 60; // 8:00 AM
const int clinicClosesAtMinutes = (16 * 60) + 30; // 4:30 PM

enum ClinicStatus { open, closed, unknown }

bool isWithinClinicHours(int hour, int minute) {
  final int totalMinutes = (hour * 60) + minute;
  return totalMinutes >= clinicOpensAtMinutes &&
      totalMinutes <= clinicClosesAtMinutes;
}

// SECURE CHECK: Get real time from internet (Malaysia Timezone) so users
// cannot bypass the opening hours by changing their device time.
// Returns unknown on a network error or timeout.
Future<ClinicStatus> checkClinicStatus() async {
  try {
    final response = await http
        .get(
          Uri.parse(
            'https://timeapi.io/api/Time/current/zone?timeZone=Asia/Kuala_Lumpur',
          ),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return ClinicStatus.unknown;

    final data = jsonDecode(response.body);
    return isWithinClinicHours(data['hour'], data['minute'])
        ? ClinicStatus.open
        : ClinicStatus.closed;
  } catch (e) {
    debugPrint("Time Check Error: $e");
    return ClinicStatus.unknown;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:qhealth/services/clinic_hours.dart';

void main() {
  test('closed just before 8:00 AM', () {
    expect(isWithinClinicHours(7, 59), isFalse);
  });

  test('open from 8:00 AM', () {
    expect(isWithinClinicHours(8, 0), isTrue);
  });

  test('open at midday', () {
    expect(isWithinClinicHours(12, 30), isTrue);
  });

  test('still open at exactly 4:30 PM', () {
    expect(isWithinClinicHours(16, 30), isTrue);
  });

  test('closed from 4:31 PM', () {
    expect(isWithinClinicHours(16, 31), isFalse);
  });
}

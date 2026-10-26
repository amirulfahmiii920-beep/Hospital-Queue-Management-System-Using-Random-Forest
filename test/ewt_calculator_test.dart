import 'package:flutter_test/flutter_test.dart';
import 'package:login_interface/services/ewt_calculator.dart';

void main() {
  group('Screening EWT', () {
    test('nobody ahead gives 5 minutes, whatever the AI says', () {
      expect(
        calculateScreeningEwt(
          patientsAhead: 0,
          maxExistingEwt: 0,
          aiBaseMinutes: 30,
        ),
        5,
      );
    });

    test('adds 5 minutes to the longest wait in the queue', () {
      expect(
        calculateScreeningEwt(
          patientsAhead: 3,
          maxExistingEwt: 40,
          aiBaseMinutes: 12,
        ),
        45,
      );
    });

    test('never goes below the AI estimate', () {
      expect(
        calculateScreeningEwt(
          patientsAhead: 1,
          maxExistingEwt: 5,
          aiBaseMinutes: 12,
        ),
        12,
      );
    });

    test('uses the 25 minute fallback when the AI is down', () {
      expect(
        calculateScreeningEwt(
          patientsAhead: 1,
          maxExistingEwt: 5,
          aiBaseMinutes: defaultScreeningBaseMinutes,
        ),
        25,
      );
    });
  });

  group('Doctor EWT', () {
    test('nobody waiting gives 5 minutes', () {
      expect(
        calculateDoctorEwt(
          patientsWaiting: 0,
          maxConsultEwt: 0,
          aiBaseMinutes: 23,
        ),
        5,
      );
    });

    test('first patient with a doctor EWT takes the AI estimate', () {
      expect(
        calculateDoctorEwt(
          patientsWaiting: 2,
          maxConsultEwt: 0,
          aiBaseMinutes: 23,
        ),
        23,
      );
    });

    test('adds 15 minutes to the longest doctor wait', () {
      expect(
        calculateDoctorEwt(
          patientsWaiting: 2,
          maxConsultEwt: 30,
          aiBaseMinutes: 23,
        ),
        45,
      );
    });

    test('never goes below the AI estimate', () {
      expect(
        calculateDoctorEwt(
          patientsWaiting: 2,
          maxConsultEwt: 5,
          aiBaseMinutes: defaultConsultBaseMinutes,
        ),
        20,
      );
    });
  });

  group('Reminder delay', () {
    test('fires 3 minutes before the estimated turn', () {
      expect(reminderDelaySeconds(10), 420);
    });

    test('is not positive when the wait is 3 minutes or less', () {
      expect(reminderDelaySeconds(3), 0);
      expect(reminderDelaySeconds(2), lessThan(0));
    });
  });
}

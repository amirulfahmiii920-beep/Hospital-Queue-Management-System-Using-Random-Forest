import 'package:flutter_test/flutter_test.dart';
import 'package:qhealth/models/queue_status.dart';
import 'package:qhealth/models/queue_ticket.dart';

void main() {
  group('QueueStatus', () {
    test('reads the text stored in Supabase', () {
      expect(QueueStatus.fromValue('Waiting'), QueueStatus.waiting);
      expect(QueueStatus.fromValue('In Progress'), QueueStatus.inProgress);
      expect(QueueStatus.fromValue('No Show'), QueueStatus.noShow);
    });

    test('treats missing or unknown text as none', () {
      expect(QueueStatus.fromValue(null), QueueStatus.none);
      expect(QueueStatus.fromValue('waiting'), QueueStatus.none);
    });

    test('only waiting and in progress are active', () {
      expect(QueueStatus.values.where((s) => s.isActive), [
        QueueStatus.waiting,
        QueueStatus.inProgress,
      ]);
    });
  });

  group('QueueTicket.fromMap', () {
    final row = {
      'id': 42,
      'patient_id': 7,
      'queue_no': 'Q-1234',
      'screening_status': 'Completed',
      'consult_status': 'Waiting',
      'screening_ewt': 12,
      'doctor_ewt': 23,
      'created_at': '2026-10-27T01:00:00Z',
      'screening_completed_at': null,
      'patients': {
        'first_name': 'Ali',
        'last_name': 'Ahmad',
        'full_name': 'Ali bin Ahmad',
      },
    };

    test('reads ids, statuses and waiting times', () {
      final ticket = QueueTicket.fromMap(row);
      expect(ticket.id, 42);
      expect(ticket.patientId, '7');
      expect(ticket.screeningStatus, QueueStatus.completed);
      expect(ticket.statusFor(consultation: true), QueueStatus.waiting);
      expect(ticket.ewtFor(consultation: false), 12);
      expect(ticket.ewtFor(consultation: true), 23);
    });

    test('converts timestamps to local time and keeps nulls', () {
      final ticket = QueueTicket.fromMap(row);
      expect(ticket.createdAt, DateTime.utc(2026, 10, 27, 1).toLocal());
      expect(ticket.screeningCompletedAt, isNull);
    });

    test('builds both display names from the joined patient', () {
      final ticket = QueueTicket.fromMap(row);
      expect(ticket.staffDisplayName, 'Ali bin Ahmad');
      expect(ticket.overviewDisplayName, 'Ali Ahmad');
    });

    test('works with a partial row and no patient', () {
      final ticket = QueueTicket.fromMap({'screening_status': 'Waiting'});
      expect(ticket.screeningStatus, QueueStatus.waiting);
      expect(ticket.consultStatus, QueueStatus.none);
      expect(ticket.screeningEwt, 0);
      expect(ticket.staffDisplayName, 'Unknown Patient');
    });
  });
}

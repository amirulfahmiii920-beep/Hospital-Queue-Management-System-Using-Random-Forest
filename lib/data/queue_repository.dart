import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/queue_status.dart';
import '../models/queue_ticket.dart';

// Every read and write on the hospital_queue table goes through here,
// so screens never build Supabase queries themselves.
class QueueRepository {
  const QueueRepository();

  static const String _table = 'hospital_queue';

  SupabaseQueryBuilder get _queue => Supabase.instance.client.from(_table);

  String _statusColumn({required bool consultation}) =>
      consultation ? 'consult_status' : 'screening_status';

  String _ewtColumn({required bool consultation}) =>
      consultation ? 'doctor_ewt' : 'screening_ewt';

  String _completedAtColumn({required bool consultation}) =>
      consultation ? 'consult_completed_at' : 'screening_completed_at';

  // ---------------- READS ----------------

  // The patient's newest ticket that was not skipped
  Future<QueueTicket?> latestTicketFor(String patientId) async {
    final row = await _queue
        .select()
        .eq('patient_id', patientId)
        .neq('screening_status', QueueStatus.noShow.value)
        .neq('consult_status', QueueStatus.noShow.value)
        .order('id', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : QueueTicket.fromMap(row);
  }

  Future<QueueTicket?> ticketById(int id) async {
    final row = await _queue.select().eq('id', id).maybeSingle();
    return row == null ? null : QueueTicket.fromMap(row);
  }

  // Patients still waiting for screening
  Future<int> countWaitingForScreening() async {
    final rows = await _queue
        .select('id')
        .eq('screening_status', QueueStatus.waiting.value);
    return rows.length;
  }

  // Patients waiting in the same stage who got their ticket before this one
  Future<int> countWaitingAhead({
    required bool consultation,
    required int ticketId,
  }) async {
    final rows = await _queue
        .select('id')
        .eq(
          _statusColumn(consultation: consultation),
          QueueStatus.waiting.value,
        )
        .lt('id', ticketId);
    return rows.length;
  }

  // Screening status and EWT of every ticket
  Future<List<QueueTicket>> screeningQueue() async {
    final rows = await _queue.select('id, screening_status, screening_ewt');
    return rows.map(QueueTicket.fromMap).toList();
  }

  // Every ticket with the patient's full name, oldest first (staff dashboard)
  Future<List<QueueTicket>> allTicketsForStaff() async {
    final rows = await _queue
        .select(
          'id, patient_id, queue_no, screening_status, consult_status, screening_ewt, doctor_ewt, created_at, screening_completed_at, consult_completed_at, patients(full_name)',
        )
        .order('id', ascending: true);
    return rows.map(QueueTicket.fromMap).toList();
  }

  // Tickets that were not skipped, with patient names (patient live overview)
  Future<List<QueueTicket>> liveTicketsWithNames() async {
    final rows = await _queue
        .select('*, patients(first_name, last_name, full_name)')
        .neq('screening_status', QueueStatus.noShow.value)
        .neq('consult_status', QueueStatus.noShow.value)
        .order('id', ascending: true);
    return rows.map(QueueTicket.fromMap).toList();
  }

  // Statuses of tickets created since [startIso] (staff daily stats)
  Future<List<QueueTicket>> statusesSince(String startIso) async {
    final rows = await _queue
        .select('screening_status, consult_status')
        .gte('created_at', startIso);
    return rows.map(QueueTicket.fromMap).toList();
  }

  // ---------------- WRITES ----------------

  // New ticket waiting for screening
  Future<QueueTicket> createTicket({
    required String queueNo,
    required String patientId,
    required int screeningEwt,
  }) async {
    final rows = await _queue.insert({
      'queue_no': queueNo,
      'patient_id': patientId,
      'screening_status': QueueStatus.waiting.value,
      'consult_status': QueueStatus.none.value,
      'screening_ewt': screeningEwt,
      'doctor_ewt': 0,
    }).select();
    return QueueTicket.fromMap(rows[0]);
  }

  // Staff calls the patient into the room
  Future<void> callPatient(int id, {required bool consultation}) => _queue
      .update({
        _statusColumn(consultation: consultation): QueueStatus.inProgress.value,
      })
      .eq('id', id);

  Future<void> setEwt(
    int id, {
    required bool consultation,
    required int minutes,
  }) => _queue
      .update({_ewtColumn(consultation: consultation): minutes})
      .eq('id', id);

  // Screening done: patient moves to the doctor queue
  Future<void> finishScreening(
    int id, {
    required int doctorEwt,
    required String completedAtIso,
  }) => _queue
      .update({
        'screening_status': QueueStatus.completed.value,
        'consult_status': QueueStatus.waiting.value,
        'doctor_ewt': doctorEwt, // Update doctor_ewt for the next patient
        'screening_completed_at': completedAtIso,
      })
      .eq('id', id);

  Future<void> finishConsultation(int id, {required String completedAtIso}) =>
      _queue
          .update({
            'consult_status': QueueStatus.completed.value,
            'consult_completed_at': completedAtIso,
          })
          .eq('id', id);

  // Marks the current stage as No Show. Staff also record when it happened.
  Future<void> markNoShow(
    int id, {
    required bool consultation,
    String? completedAtIso,
  }) => _queue
      .update({
        _statusColumn(consultation: consultation): QueueStatus.noShow.value,
        if (completedAtIso != null)
          _completedAtColumn(consultation: consultation): completedAtIso,
      })
      .eq('id', id);

  Future<void> confirmPresence(int id) =>
      _queue.update({'is_present': true}).eq('id', id);
}

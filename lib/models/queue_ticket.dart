import 'queue_status.dart';

// One row of the hospital_queue table.
// Fields that were not selected in a query fall back to empty values.
class QueueTicket {
  const QueueTicket({
    required this.id,
    required this.patientId,
    required this.queueNo,
    required this.screeningStatus,
    required this.consultStatus,
    required this.screeningEwt,
    required this.doctorEwt,
    this.createdAt,
    this.screeningCompletedAt,
    this.consultCompletedAt,
    this.isPresent = false,
    this.hasPatientRecord = false,
    this.patientFullName,
    this.patientFirstName = '',
    this.patientLastName = '',
  });

  final int id;
  final String patientId;
  final String queueNo;
  final QueueStatus screeningStatus;
  final QueueStatus consultStatus;

  // Estimated waiting time in minutes for each stage
  final int screeningEwt;
  final int doctorEwt;

  // Timestamps are converted to the phone's local time
  final DateTime? createdAt;
  final DateTime? screeningCompletedAt;
  final DateTime? consultCompletedAt;

  final bool isPresent;

  // From the joined patients table, when the query asks for it
  final bool hasPatientRecord;
  final String? patientFullName;
  final String patientFirstName;
  final String patientLastName;

  factory QueueTicket.fromMap(Map<String, dynamic> map) {
    final patient = map['patients'];
    final bool hasPatient = patient != null && patient is Map;

    return QueueTicket(
      id: map['id'] as int? ?? 0,
      patientId: map['patient_id']?.toString() ?? '',
      queueNo: map['queue_no']?.toString() ?? '',
      screeningStatus: QueueStatus.fromValue(map['screening_status']),
      consultStatus: QueueStatus.fromValue(map['consult_status']),
      screeningEwt: map['screening_ewt'] as int? ?? 0,
      doctorEwt: map['doctor_ewt'] as int? ?? 0,
      createdAt: _parseTime(map['created_at']),
      screeningCompletedAt: _parseTime(map['screening_completed_at']),
      consultCompletedAt: _parseTime(map['consult_completed_at']),
      isPresent: map['is_present'] == true,
      hasPatientRecord: hasPatient,
      patientFullName: hasPatient ? patient['full_name'] : null,
      patientFirstName: hasPatient ? (patient['first_name'] ?? '') : '',
      patientLastName: hasPatient ? (patient['last_name'] ?? '') : '',
    );
  }

  static DateTime? _parseTime(dynamic value) =>
      value == null ? null : DateTime.parse(value.toString()).toLocal();

  // Status and EWT of the stage the patient is in
  QueueStatus statusFor({required bool consultation}) =>
      consultation ? consultStatus : screeningStatus;

  int ewtFor({required bool consultation}) =>
      consultation ? doctorEwt : screeningEwt;

  // Full name as shown on the staff dashboard
  String get staffDisplayName =>
      hasPatientRecord ? (patientFullName ?? 'Unknown') : 'Unknown Patient';

  // First and last name as shown on the patient's live queue overview
  String get overviewDisplayName {
    if (!hasPatientRecord) return 'Unknown Patient';
    if (patientFirstName.isNotEmpty || patientLastName.isNotEmpty) {
      return '$patientFirstName $patientLastName'.trim();
    }
    return patientFullName ?? '';
  }
}

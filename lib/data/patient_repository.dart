import 'package:supabase_flutter/supabase_flutter.dart';

// Reads and writes on the patients table.
class PatientRepository {
  const PatientRepository();

  SupabaseQueryBuilder get _patients =>
      Supabase.instance.client.from('patients');

  Future<Map<String, dynamic>?> findByUsername(String username) =>
      _patients.select().eq('username', username).maybeSingle();

  Future<Map<String, dynamic>?> findByEmail(String email) =>
      _patients.select().eq('email', email).maybeSingle();

  Future<Map<String, dynamic>?> findById(String id) =>
      _patients.select().eq('id', id).maybeSingle();

  Future<void> create(Map<String, dynamic> patient) =>
      _patients.insert(patient);

  // Inserts the patient and returns the saved row (with its new id)
  Future<Map<String, dynamic>> createAndReturn(Map<String, dynamic> patient) =>
      _patients.insert(patient).select().single();

  Future<void> update(String id, Map<String, dynamic> changes) =>
      _patients.update(changes).eq('id', id);
}

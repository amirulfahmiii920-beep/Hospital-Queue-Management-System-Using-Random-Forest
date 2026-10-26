import 'package:supabase_flutter/supabase_flutter.dart';

// Reads on the staff table.
class StaffRepository {
  const StaffRepository();

  Future<Map<String, dynamic>?> findByStaffId(String staffId) => Supabase
      .instance
      .client
      .from('staff')
      .select()
      .eq('staff_id', staffId)
      .maybeSingle();
}

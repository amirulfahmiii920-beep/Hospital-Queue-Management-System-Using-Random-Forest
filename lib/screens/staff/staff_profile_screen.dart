import 'package:flutter/material.dart';

import '../../core/queue_data.dart';
import '../../data/queue_repository.dart';
import '../../models/queue_status.dart';
import '../../widgets/staff_nav_bar.dart';
import 'staff_login_screen.dart';

// 14. STAFF PROFILE SCREEN (DYNAMIC)
class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  final QueueRepository _queue = const QueueRepository();

  int _completedToday = 0;
  int _pendingPatients = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchStaffStats();
  }

  // FUNCTION: FETCH STAFF STATS (COMPLETED & PENDING)
  Future<void> _fetchStaffStats() async {
    try {
      // Set the start of the day
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      String startIso = startOfDay.toUtc().toIso8601String();

      // Fetch all patients for today only from the database
      final tickets = await _queue.statusesSince(startIso);

      int completed = 0;
      int pending = 0;

      for (var ticket in tickets) {
        QueueStatus sStatus = ticket.screeningStatus;
        QueueStatus cStatus = ticket.consultStatus;

        // Calculate how many patients have completed their process
        if (sStatus == QueueStatus.completed ||
            cStatus == QueueStatus.completed) {
          completed++;
        }
        // Calculate how many patients are still waiting
        if (sStatus == QueueStatus.waiting || cStatus == QueueStatus.waiting) {
          pending++;
        }
      }

      if (mounted) {
        setState(() {
          _completedToday = completed;
          _pendingPatients = pending;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching staff stats: $e");
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      bottomNavigationBar: buildStaffBottomNavBar(
        context,
        currentIndex: 2, // Highlight tab Profile
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  // PROFILE AVATAR & DETAILS
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white12,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    QueueData.currentStaffName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${QueueData.currentStaffRole} | Staff ID: ${QueueData.currentStaffDisplayId}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 10),
                        SizedBox(width: 8),
                        Text(
                          'On Duty - Morning Shift',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // DYNAMIC STATS CARDS (COMPLETED & PENDING)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Completed Today',
                    value: _isLoadingStats ? '...' : '$_completedToday',
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildStatCard(
                    title: 'Pending Patients',
                    value: _isLoadingStats ? '...' : '$_pendingPatients',
                    icon: Icons.people_outline,
                    iconColor: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _buildMenuOption(
                    context: context,
                    icon: Icons.person_outline,
                    title: 'Edit Personal Details',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuOption(
                    context: context,
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuOption(
                    context: context,
                    icon: Icons.notifications_none,
                    title: 'Notification Settings',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StaffLoginScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.tealAccent, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Colors.white.withValues(alpha: 0.3),
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withValues(alpha: 0.1),
      height: 1,
      thickness: 1,
      indent: 60,
      endIndent: 20,
    );
  }
}

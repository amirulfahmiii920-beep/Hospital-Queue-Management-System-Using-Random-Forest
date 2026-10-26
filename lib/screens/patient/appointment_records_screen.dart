import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/app_base_screen.dart';

class AppointmentRecordsScreen extends StatelessWidget {
  const AppointmentRecordsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    'Appointment Records',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upcoming',
                      style: TextStyle(
                        color: Colors.pinkAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildAppointmentCard(
                      date: '15 April 2026',
                      time: '10:00 AM',
                      doctor: 'Dr. Afiq Firdaus',
                      department: 'Outpatient',
                      status: 'Confirmed',
                      statusColor: Colors.teal,
                      isUpcoming: true,
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Past Records',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildAppointmentCard(
                      date: '10 Jan 2026',
                      time: '02:30 PM',
                      doctor: 'Dr. Sarah',
                      department: 'Outpatient',
                      status: 'Completed',
                      statusColor: AppTheme.textSecondary,
                      isUpcoming: false,
                    ),
                    const SizedBox(height: 15),
                    _buildAppointmentCard(
                      date: '22 Nov 2026',
                      time: '09:15 AM',
                      doctor: 'Dr. Afiq Firdaus',
                      department: 'Outpatient',
                      status: 'Completed',
                      statusColor: AppTheme.textSecondary,
                      isUpcoming: false,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard({
    required String date,
    required String time,
    required String doctor,
    required String department,
    required String status,
    required Color statusColor,
    required bool isUpcoming,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.glassBorder, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: isUpcoming
                            ? Colors.pinkAccent
                            : AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        date,
                        style: TextStyle(
                          color: isUpcoming
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    time,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(height: 1, color: AppTheme.dividerColor),
              const SizedBox(height: 15),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.avatarBg,
                    radius: 18,
                    child: Text(
                      doctor[4],
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        department,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isUpcoming) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: BorderSide(color: AppTheme.glassBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {},
                        child: const Text('Reschedule'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent.withValues(
                            alpha: 0.1,
                          ),
                          foregroundColor: Colors.pinkAccent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {},
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

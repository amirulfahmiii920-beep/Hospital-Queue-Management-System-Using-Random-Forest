import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/queue_data.dart';
import '../../services/ai_server_service.dart';
import '../../services/clinic_hours.dart';
import '../../services/ewt_calculator.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/app_base_screen.dart';
import '../../widgets/patient_nav_bar.dart';
import 'home_screen.dart';

// 11. PAGE TO GET QUEUE NUMBER AND ESTIMATED WAIT TIME FROM SUPABASE
class GetQueueScreen extends StatefulWidget {
  const GetQueueScreen({super.key});
  @override
  State<GetQueueScreen> createState() => _GetQueueScreenState();
}

class _GetQueueScreenState extends State<GetQueueScreen> {
  bool _isLoading = false;
  bool _hasQueue = false;
  String _assignedQueueNumber = '';
  int _estimatedWaitTime = 0;

  // Variable to prevent multiple button presses
  bool _isCheckingTime = false;

  void _generateQueue() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. COUNT PATIENTS CURRENTLY WAITING IN SCREENING
      final countResponse = await supabase
          .from('hospital_queue')
          .select('id')
          .eq('screening_status', 'Waiting');

      int patientsAheadCount = countResponse.length;

      // 2. GET BASE EWT FROM AI (PYTHON SERVER)
      // ONLY CALL AI SERVER IF THERE ARE PATIENTS AHEAD
      int baseWaitTime = defaultScreeningBaseMinutes;
      if (patientsAheadCount > 0) {
        baseWaitTime = await fetchScreeningEstimate() ?? baseWaitTime;
      }

      // 3. GET MAX EXISTING EWT FROM SUPABASE FOR PATIENTS WITH STATUS "Waiting" OR "In Progress"
      final queueResponse = await supabase
          .from('hospital_queue')
          .select('id, screening_status, screening_ewt');

      int maxExistingEwt = 0;
      for (var record in queueResponse) {
        String status = record['screening_status'] ?? '';
        if (status == 'Waiting' || status == 'In Progress') {
          int ewt = record['screening_ewt'] ?? 0;
          if (ewt > maxExistingEwt) {
            maxExistingEwt = ewt;
          }
        }
      }

      int calculatedWaitTime = calculateScreeningEwt(
        patientsAhead: patientsAheadCount,
        maxExistingEwt: maxExistingEwt,
        aiBaseMinutes: baseWaitTime,
      );

      // 4. GET CURRENT USER ID FROM QUEUE DATA
      String validPatientId = QueueData.currentUserId;

      if (validPatientId.isEmpty) {
        throw Exception("Session expired. Please log out and login again.");
      }

      OneSignal.login(validPatientId);
      // 5. INSERT DATA INTO NEW TABLE: hospital_queue
      String generatedQueueNo =
          'Q-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';

      final response = await supabase.from('hospital_queue').insert({
        'queue_no': generatedQueueNo,
        'patient_id': validPatientId,
        'screening_status': 'Waiting',
        'consult_status': 'None',
        'screening_ewt': calculatedWaitTime,
        'doctor_ewt': 0,
      }).select();

      if (mounted) {
        setState(() {
          _assignedQueueNumber = response[0]['id'].toString();
          _estimatedWaitTime = response[0]['screening_ewt'] as int;
          _isLoading = false;
          _hasQueue = true;
        });

        QueueData.updateQueueInfo(
          _assignedQueueNumber,
          _estimatedWaitTime,
          patientsAheadCount,
        );

        // SCHEDULE PUSH NOTIFICATION FOR SCREENING
        int delayInSeconds = reminderDelaySeconds(
          _estimatedWaitTime,
        ); // Trigger 3 mins before
        if (delayInSeconds > 0) {
          sendScheduledPushNotification(
            validPatientId,
            "Your Turn is Near!",
            "Only 3 minutes left until your screening. Please open the app to confirm your presence.",
            delayInSeconds,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting queue: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      bottomNavBar: buildGlassBottomNavBar(context, currentIndex: 2),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    ),
                    child: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'Queue Access',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AppTheme.glassBg,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppTheme.glassBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading) ...[
                          const CircularProgressIndicator(
                            color: Colors.pinkAccent,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Contacting AI Server...',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ] else if (_hasQueue) ...[
                          // UI TIKET BERJAYA DIAMBIL
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 30,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.pinkAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Your Queue Number',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _assignedQueueNumber,
                                  style: const TextStyle(
                                    color: Colors.pinkAccent,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),
                          Text(
                            'Estimated Wait: ${QueueData.getFormattedEWT(_estimatedWaitTime)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Please wait nearby. We will notify you when it is your turn.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ] else ...[
                          // UI DEFAULT (TICKET ICON)
                          Icon(
                            Icons.confirmation_num_outlined,
                            size: 100,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Digital Queue',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Request a queue number and get your estimated waiting time instantly.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 35),

                          // NEW BUTTON LOGIC: GET QUEUE (ONLINE TIME CHECK)
                          ValueListenableBuilder<bool>(
                            valueListenable: QueueData.isQueueActive,
                            builder: (context, isActive, child) {
                              // We keep local time just for button display colors (Gray vs Green)
                              final now = DateTime.now();
                              bool isWithinHoursLocal = isWithinClinicHours(
                                now.hour,
                                now.minute,
                              );
                              bool isButtonDisabled =
                                  isActive || !isWithinHoursLocal;

                              return GestureDetector(
                                onTap: _isCheckingTime
                                    ? null
                                    : () async {
                                        // 1. If already in queue, block immediately
                                        if (isActive) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please wait until your session is fully completed to request a new one.',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        // 2. Show loading while checking internet time
                                        setState(() => _isCheckingTime = true);

                                        // 3. SECURE CHECK: Get real time from internet (Malaysia Timezone) to prevent users from bypassing the system by changing their device time
                                        ClinicStatus status =
                                            await checkClinicStatus();

                                        if (mounted) {
                                          setState(
                                            () => _isCheckingTime = false,
                                          );
                                        }

                                        if (status == ClinicStatus.open) {
                                          // STATUS 1: SYSTEM OPEN!
                                          _generateQueue();
                                        } else if (status ==
                                            ClinicStatus.closed) {
                                          // STATUS 0: SYSTEM CLOSED (OUT OF OPERATING HOURS)
                                          if (!context.mounted) return;
                                          {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                backgroundColor:
                                                    AppTheme.isDark.value
                                                    ? Colors.grey[900]
                                                    : Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                title: Text(
                                                  "Out of Operating Hours",
                                                  style: TextStyle(
                                                    color: AppTheme.textPrimary,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                content: Text(
                                                  "The outpatient clinic operates strictly from 8:00 AM to 4:30 PM (Malaysia Time).\n\nIf you are experiencing a medical emergency, please proceed directly to the Emergency Department immediately.",
                                                  style: TextStyle(
                                                    color:
                                                        AppTheme.textSecondary,
                                                    height: 1.4,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text(
                                                      "Understood",
                                                      style: TextStyle(
                                                        color:
                                                            Colors.pinkAccent,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        } else {
                                          // STATUS 2: INTERNET ERROR / SERVER API
                                          if (!context.mounted) return;
                                          {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Connection error. Please check your internet connection to get a queue number.',
                                                ),
                                                backgroundColor: Colors.red,
                                                duration: Duration(seconds: 4),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                child: Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: isButtonDisabled
                                        ? Colors.grey.withValues(alpha: 0.2)
                                        : Colors.teal.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: isButtonDisabled
                                          ? Colors.grey.withValues(alpha: 0.5)
                                          : Colors.teal.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: _isCheckingTime
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.teal,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Get Queue Number',
                                          style: TextStyle(
                                            color: isButtonDisabled
                                                ? Colors.grey
                                                : Colors.teal,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

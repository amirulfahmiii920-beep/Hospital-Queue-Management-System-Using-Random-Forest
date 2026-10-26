import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/queue_data.dart';
import '../../services/ai_server_service.dart';
import '../../services/ewt_calculator.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/staff_nav_bar.dart';

// 13. STAFF DASHBOARD (Screening & Consultation)
class StaffHomeScreen extends StatefulWidget {
  final bool isConsultation;

  const StaffHomeScreen({super.key, this.isConsultation = false});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _selectedTabIndex = 0;
  Timer? _refreshTimer;

  static List<Map<String, dynamic>> _queueList = [];

  // TAB NAME
  List<String> get _tabs => [
    'Waiting',
    widget.isConsultation ? 'Consulting' : 'Screening',
    'No Show',
  ];

  @override
  void initState() {
    super.initState();
    _fetchQueueData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchQueueData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // FILTER QUEUE BASED ON SELECTED TAB
  List<Map<String, dynamic>> get _filteredQueue {
    String statusToMatch = _tabs[_selectedTabIndex];
    // If the tab is "Screening" or "Consulting", we treat it as "In Progress" for filtering
    if (statusToMatch == 'Screening' || statusToMatch == 'Consulting') {
      statusToMatch = 'In Progress';
    }

    if (widget.isConsultation) {
      return _queueList
          .where((p) => p['consult_status'] == statusToMatch)
          .toList();
    } else {
      return _queueList
          .where((p) => p['screening_status'] == statusToMatch)
          .toList();
    }
  }

  int get _totalWaiting {
    if (widget.isConsultation) {
      return _queueList.where((p) => p['consult_status'] == 'Waiting').length;
    } else {
      return _queueList.where((p) => p['screening_status'] == 'Waiting').length;
    }
  }

  // LATEST CODE : (LONGEST WAIT)
  Map<String, String> get _longestWaitData {
    List<Map<String, dynamic>> waitingList = widget.isConsultation
        ? _queueList.where((p) => p['consult_status'] == 'Waiting').toList()
        : _queueList.where((p) => p['screening_status'] == 'Waiting').toList();

    if (waitingList.isEmpty) {
      return {'time': '0 mins', 'name': 'No patients'};
    }

    DateTime now = DateTime.now();
    int maxMins = -1;
    String longestPatientName = '';

    for (var p in waitingList) {
      DateTime? startTime = widget.isConsultation
          ? (p['screening_completed_at'] != null
                ? DateTime.parse(p['screening_completed_at']).toLocal()
                : null)
          : (p['created_at'] != null
                ? DateTime.parse(p['created_at']).toLocal()
                : null);

      if (startTime != null) {
        int mins = now.difference(startTime).inMinutes;
        if (mins > maxMins) {
          maxMins = mins;
          longestPatientName = p['name'] ?? 'Unknown';
        }
      }
    }

    if (maxMins < 0) maxMins = 0;

    String formattedTime;
    if (maxMins >= 60) {
      int hrs = maxMins ~/ 60;
      int m = maxMins % 60;
      formattedTime = "$hrs hr $m min";
    } else {
      formattedTime = "$maxMins mins";
    }

    return {'time': formattedTime, 'name': longestPatientName};
  }

  String _formatDuration(DateTime start, DateTime? end) {
    DateTime endTime = end ?? DateTime.now();
    Duration diff = endTime.difference(start);
    int mins = diff.inMinutes;
    if (mins < 1) return "Just now";
    if (mins > 60) {
      int hrs = mins ~/ 60;
      int leftMins = mins % 60;
      return "$hrs hr $leftMins min";
    }
    return "$mins mins";
  }

  Future<void> _fetchQueueData() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('hospital_queue')
          .select(
            'id, patient_id, queue_no, screening_status, consult_status, screening_ewt, doctor_ewt, created_at, screening_completed_at, consult_completed_at, patients(full_name)',
          )
          .order('id', ascending: true);

      if (mounted) {
        setState(() {
          _queueList = List<Map<String, dynamic>>.from(response).map((item) {
            final patientData = item['patients'] as Map<String, dynamic>?;
            item['name'] = patientData != null
                ? patientData['full_name']
                : 'Unknown Patient';
            return item;
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching queue: $e");
    }
  }

  // HANDLE CALLING PATIENT (UPDATE STATUS + SEND PUSH NOTIFICATION)
  void _handleCallPatient(Map<String, dynamic> patient) async {
    final supabase = Supabase.instance.client;
    try {
      if (widget.isConsultation) {
        await supabase
            .from('hospital_queue')
            .update({'consult_status': 'In Progress'})
            .eq('id', patient['id']);
      } else {
        await supabase
            .from('hospital_queue')
            .update({'screening_status': 'In Progress'})
            .eq('id', patient['id']);
      }

      String targetId = patient['patient_id'].toString();
      await sendPushNotification(
        targetId,
        "It's Your Turn!",
        "The staff is calling you. Please proceed to the room immediately.",
      );

      _fetchQueueData();
    } catch (e) {
      debugPrint("Error calling patient: $e");
    }
  }

  void _addTimeToQueue(int extraMins) async {
    try {
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> waitingList = _filteredQueue;
      for (var p in waitingList) {
        if (widget.isConsultation) {
          int newEwt = (p['doctor_ewt'] as int) + extraMins;
          await supabase
              .from('hospital_queue')
              .update({'doctor_ewt': newEwt})
              .eq('id', p['id']);
        } else {
          int newEwt = (p['screening_ewt'] as int) + extraMins;
          await supabase
              .from('hospital_queue')
              .update({'screening_ewt': newEwt})
              .eq('id', p['id']);
        }
      }
      _fetchQueueData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $extraMins minutes delay to the queue.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding time: $e");
    }
  }

  void _showAddTimeDialog(Map<String, dynamic> patient) {
    final TextEditingController timeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppTheme.glassBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.more_time,
                      color: Colors.orangeAccent,
                      size: 50,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Delay / Extra Time',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Patient ${patient['name']} is taking longer than expected. Enter extra time (in minutes) to delay the entire queue:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.orangeAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: TextField(
                        controller: timeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'e.g. 12',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              int extraMins =
                                  int.tryParse(timeController.text) ?? 0;
                              if (extraMins > 0) {
                                _addTimeToQueue(extraMins);
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePatientDone(Map<String, dynamic> patient) async {
    final supabase = Supabase.instance.client;
    String nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      if (!widget.isConsultation) {
        // 1. CALCULATE MAXIMUM CONSULTATION EWT FROM QUEUE
        int maxConsultEwt = 0;
        int patientsWaitingForDoc = 0;

        for (var p in _queueList) {
          String cStatus = p['consult_status'] ?? '';
          if (cStatus == 'Waiting' || cStatus == 'In Progress') {
            patientsWaitingForDoc++;
            int ewt = p['doctor_ewt'] ?? 0;
            if (ewt > maxConsultEwt) {
              maxConsultEwt = ewt;
            }
          }
        }

        // 2. CALL AI SERVER TO GET ESTIMATED CONSULTATION WAIT TIME
        int baseConsultWaitTime =
            await fetchConsultEstimate(queueLength: patientsWaitingForDoc) ??
            defaultConsultBaseMinutes;

        // 3. CALCULATE NEW DOCTOR EWT BASED ON QUEUE LENGTH AND AI PREDICTION
        int newDoctorEwt = calculateDoctorEwt(
          patientsWaiting: patientsWaitingForDoc,
          maxConsultEwt: maxConsultEwt,
          aiBaseMinutes: baseConsultWaitTime,
        );

        // 4. UPDATE DATABASE SUPABASE
        await supabase
            .from('hospital_queue')
            .update({
              'screening_status': 'Completed',
              'consult_status': 'Waiting',
              'doctor_ewt':
                  newDoctorEwt, // Update doctor_ewt for the next patient
              'screening_completed_at': nowIso,
            })
            .eq('id', patient['id']);

        // Update QueueData.queueStage if the current patient is the one being processed
        if (QueueData.myQueueNumber == patient['queue_no']) {
          QueueData.queueStage.value = 'Consultation';
        }
        int delayConsult = reminderDelaySeconds(newDoctorEwt);
        if (delayConsult > 0) {
          sendScheduledPushNotification(
            patient['patient_id'].toString(),
            "Doctor Consultation Ready",
            "Only 3 minutes left to see the doctor. Please get ready.",
            delayConsult,
          );
        }
      } else {
        // IF CONSULTATION IS DONE, MARK AS COMPLETED
        await supabase
            .from('hospital_queue')
            .update({
              'consult_status': 'Completed',
              'consult_completed_at': nowIso,
            })
            .eq('id', patient['id']);
      }

      await _fetchQueueData();

      // QUEUE TIME REDUCTION & DYNAMIC NOTIFICATION SYSTEM
      List<Map<String, dynamic>> waitingList = widget.isConsultation
          ? _queueList.where((p) => p['consult_status'] == 'Waiting').toList()
          : _queueList
                .where((p) => p['screening_status'] == 'Waiting')
                .toList();

      if (waitingList.isNotEmpty) {
        var nextPatient = waitingList.first;
        int oldEwt = widget.isConsultation
            ? nextPatient['doctor_ewt']
            : nextPatient['screening_ewt'];

        if (oldEwt > 5) {
          int timeSaved = oldEwt - 5;
          for (var p in waitingList) {
            int updatedEwt;
            String targetId = p['patient_id'].toString();

            // 1. UPDATE NEW TIME IN DATABASE
            if (widget.isConsultation) {
              updatedEwt = p['doctor_ewt'] - timeSaved;
              if (updatedEwt < 0) updatedEwt = 0;
              await supabase
                  .from('hospital_queue')
                  .update({'doctor_ewt': updatedEwt})
                  .eq('id', p['id']);
            } else {
              updatedEwt = p['screening_ewt'] - timeSaved;
              if (updatedEwt < 0) updatedEwt = 0;
              await supabase
                  .from('hospital_queue')
                  .update({'screening_ewt': updatedEwt})
                  .eq('id', p['id']);
            }

            // 2. FIRE LIVE NOTIFICATION IF TIME CHANGES DRASTICALLY
            if (updatedEwt > 0 && updatedEwt <= 3) {
              sendPushNotification(
                targetId,
                "Your Turn is Near!",
                "Queue moved fast! You have roughly $updatedEwt minutes left. Please get ready.",
              );
            } else if (updatedEwt > 3) {
              sendPushNotification(
                targetId,
                "Wait Time Reduced",
                "A patient finished early. Your waiting time is reduced by $timeSaved minutes.",
              );
            }
          }

          if (QueueData.myQueueNumber == nextPatient['queue_no']) {
            QueueData.remainingSeconds.value = 301;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !widget.isConsultation
                  ? '${patient['name']} screening completed.'
                  : '${patient['name']} consultation completed.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error completing patient: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredQueue;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      bottomNavigationBar: buildStaffBottomNavBar(
        context,
        currentIndex: widget.isConsultation ? 1 : 0,
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isConsultation
              ? 'Consultation Dashboard'
              : 'Screening Dashboard',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStaffStatCard(
                    'Total Waiting',
                    '$_totalWaiting',
                    Icons.people_outline,
                    widget.isConsultation
                        ? Colors.blueAccent
                        : Colors.tealAccent,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildStaffStatCard(
                    'Longest Wait',
                    _longestWaitData['time']!,
                    Icons.timer_off_outlined,
                    Colors.redAccent,
                    patientName: _longestWaitData['name'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  bool isActive = _selectedTabIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedTabIndex = index;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (widget.isConsultation
                                  ? Colors.blueAccent
                                  : Colors.teal)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? (widget.isConsultation
                                    ? Colors.blue
                                    : Colors.tealAccent)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        _tabs[index],
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Text(
                        'No records found',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final patient = filteredList[index];
                        bool isWaitingTab = _selectedTabIndex == 0;
                        bool isInProgressTab = _selectedTabIndex == 1;
                        Color themeColor = widget.isConsultation
                            ? Colors.blueAccent
                            : Colors.tealAccent;

                        String timeLabel = '';
                        String timeValue = '';

                        DateTime? createdAt = patient['created_at'] != null
                            ? DateTime.parse(patient['created_at']).toLocal()
                            : null;
                        DateTime? screenCompletedAt =
                            patient['screening_completed_at'] != null
                            ? DateTime.parse(
                                patient['screening_completed_at'],
                              ).toLocal()
                            : null;
                        DateTime? consultCompletedAt =
                            patient['consult_completed_at'] != null
                            ? DateTime.parse(
                                patient['consult_completed_at'],
                              ).toLocal()
                            : null;

                        if (!widget.isConsultation) {
                          if (isWaitingTab) {
                            timeLabel = 'Waiting for:';
                            timeValue = createdAt != null
                                ? _formatDuration(createdAt, null)
                                : '-';
                          } else if (isInProgressTab) {
                            timeLabel = 'Started:';
                            timeValue = createdAt != null
                                ? _formatDuration(createdAt, null)
                                : '-';
                          } else {
                            timeLabel = 'Total waited:';
                            timeValue =
                                (createdAt != null && screenCompletedAt != null)
                                ? _formatDuration(createdAt, screenCompletedAt)
                                : '-';
                          }
                        } else {
                          if (isWaitingTab) {
                            timeLabel = 'Waiting for doctor:';
                            timeValue = screenCompletedAt != null
                                ? _formatDuration(screenCompletedAt, null)
                                : 'Calculating...';
                          } else if (isInProgressTab) {
                            timeLabel = 'Consulting for:';
                            timeValue = screenCompletedAt != null
                                ? _formatDuration(screenCompletedAt, null)
                                : '-';
                          } else {
                            timeLabel = 'Total waited for doctor:';
                            timeValue =
                                (screenCompletedAt != null &&
                                    consultCompletedAt != null)
                                ? _formatDuration(
                                    screenCompletedAt,
                                    consultCompletedAt,
                                  )
                                : '-';
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isInProgressTab
                                ? themeColor.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isInProgressTab
                                  ? themeColor
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isInProgressTab
                                        ? themeColor
                                        : Colors.black26,
                                    child: Text(
                                      patient['queue_no'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          patient['name'],
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),

                                        // ATTENDANCE STATUS (PENDING ARRIVAL / PRESENT / NOT PRESENT)
                                        Builder(
                                          builder: (context) {
                                            // 1. Calculate remaining time
                                            int assignedEwt =
                                                widget.isConsultation
                                                ? (patient['doctor_ewt'] ?? 0)
                                                : (patient['screening_ewt'] ??
                                                      0);
                                            int elapsedMins = 0;

                                            if (!widget.isConsultation &&
                                                createdAt != null) {
                                              elapsedMins = DateTime.now()
                                                  .difference(createdAt)
                                                  .inMinutes;
                                            } else if (widget.isConsultation &&
                                                screenCompletedAt != null) {
                                              elapsedMins = DateTime.now()
                                                  .difference(screenCompletedAt)
                                                  .inMinutes;
                                            }

                                            int remainingMins =
                                                assignedEwt - elapsedMins;

                                            // 2. Determine status
                                            bool isPresent =
                                                patient['is_present'] == true;
                                            bool isTimeUp = remainingMins <= 0;

                                            String presenceText =
                                                "PENDING ARRIVAL";
                                            Color presenceColor =
                                                Colors.orangeAccent;

                                            if (isPresent) {
                                              presenceText =
                                                  "PRESENT"; // User has arrived and marked present
                                              presenceColor =
                                                  Colors.greenAccent;
                                            } else if (isTimeUp) {
                                              presenceText =
                                                  "NOT PRESENT"; // User has not arrived and time is up
                                              presenceColor = Colors.redAccent;
                                            }

                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: presenceColor.withValues(
                                                  alpha: 0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                presenceText,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: presenceColor,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 6),
                                        // ==========================================
                                        const SizedBox(height: 4),
                                        if (isWaitingTab)
                                          Text(
                                            widget.isConsultation
                                                ? 'EWT: ${patient['doctor_ewt']} mins'
                                                : 'EWT: ${patient['screening_ewt']} mins',
                                            style: const TextStyle(
                                              color: Colors.orangeAccent,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        if (isWaitingTab)
                                          const SizedBox(height: 4),
                                        Text(
                                          '$timeLabel $timeValue',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ACTION BUTTONS (SKIP / + TIME / CALL / MARK AS DONE)
                              if (isWaitingTab) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final supabase =
                                              Supabase.instance.client;
                                          String nowIso = DateTime.now()
                                              .toUtc()
                                              .toIso8601String();
                                          if (widget.isConsultation) {
                                            await supabase
                                                .from('hospital_queue')
                                                .update({
                                                  'consult_status': 'No Show',
                                                  'consult_completed_at':
                                                      nowIso,
                                                })
                                                .eq('id', patient['id']);
                                          } else {
                                            await supabase
                                                .from('hospital_queue')
                                                .update({
                                                  'screening_status': 'No Show',
                                                  'screening_completed_at':
                                                      nowIso,
                                                })
                                                .eq('id', patient['id']);
                                          }
                                          _fetchQueueData();
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        child: const Text(
                                          'Skip',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _showAddTimeDialog(patient),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Colors.orangeAccent,
                                          ),
                                        ),
                                        child: const Text(
                                          '+ Time',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _handleCallPatient(patient),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: themeColor,
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text(
                                          'Call',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (isInProgressTab) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _handlePatientDone(patient),
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      'Mark as Done',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor, {
    String? patientName,
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
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (patientName != null) ...[
            const SizedBox(height: 4),
            Text(
              patientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text(' ', style: TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

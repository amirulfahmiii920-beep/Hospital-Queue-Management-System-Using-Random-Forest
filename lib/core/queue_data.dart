import 'dart:async';

import 'package:flutter/material.dart';

import '../data/queue_repository.dart';
import '../models/queue_status.dart';

// =========================================================================
// 2.5 GLOBAL MEMORY (To ensure data doesn't get lost when switching screens)
// =========================================================================
class QueueData {
  static const QueueRepository _queue = QueueRepository();

  static String currentUserId = '';
  static String currentUserName = 'Guest';
  // LATEST CODE: Global Memory for Staff
  static String currentStaffTableId = '';
  static String currentStaffName = 'Staff';
  static String currentStaffRole = 'Nurse';
  static String currentStaffDisplayId = '-';
  static ValueNotifier<int> remainingSeconds = ValueNotifier(0);
  static ValueNotifier<bool> isQueueActive = ValueNotifier(false);
  static ValueNotifier<bool> showCheckInDialog = ValueNotifier(false);

  static ValueNotifier<String> queueStage = ValueNotifier('Screening');
  static ValueNotifier<String> patientStatusText = ValueNotifier(
    'Welcome! Please get a queue number below to start your session.',
  );

  static ValueNotifier<List<Map<String, dynamic>>> myNotifications =
      ValueNotifier([]);

  static bool hasConfirmedPresence = false;
  static int startSeconds = 0;
  static String myQueueNumber = '-';

  static ValueNotifier<int> patientsAhead = ValueNotifier(0);
  static int _tickCount = 0;

  static Timer? timer;
  static Timer? autoSkipTimer;
  static Timer? backgroundSyncTimer;

  static void clearData() {
    currentUserId = '';
    currentUserName = 'Guest';
    currentStaffTableId = '';
    currentStaffName = 'Staff';
    currentStaffRole = 'Nurse';
    currentStaffDisplayId = '-';
    myQueueNumber = '-';
    startSeconds = 0;
    remainingSeconds.value = 0;
    isQueueActive.value = false;
    showCheckInDialog.value = false;
    queueStage.value = 'Screening';
    patientStatusText.value =
        'Welcome! Please get a queue number below to start your session.';
    patientsAhead.value = 0;
    hasConfirmedPresence = false;
    myNotifications.value = [];
    timer?.cancel();
    autoSkipTimer?.cancel();
    backgroundSyncTimer?.cancel();
  }

  static String getFormattedEWT(int totalMins) {
    if (totalMins < 60) return '$totalMins mins';
    int hours = totalMins ~/ 60;
    int minutes = totalMins % 60;
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes mins';
  }

  static String _getCurrentTime() {
    final now = DateTime.now();
    String hour = now.hour > 12
        ? (now.hour - 12).toString()
        : now.hour.toString();
    if (hour == '0') hour = '12';
    String min = now.minute.toString().padLeft(2, '0');
    String ampm = now.hour >= 12 ? 'PM' : 'AM';
    return 'Today at $hour:$min $ampm';
  }

  static void addNotification({
    required String title,
    required String message,
    bool requiresAction = false,
  }) {
    final newNotif = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'message': message,
      'time': _getCurrentTime(),
      'isRead': false,
      'requiresAction': requiresAction,
      'isActioned': false,
    };
    myNotifications.value = [newNotif, ...myNotifications.value];
  }

  static void updateQueueInfo(String queueNo, int mins, int ahead) {
    myQueueNumber = queueNo;
    patientsAhead.value = ahead;
    startSeconds = mins * 60;
    remainingSeconds.value = startSeconds;
    queueStage.value = 'Screening';
    patientStatusText.value = 'Waiting for Screening...';
    isQueueActive.value = true;
    hasConfirmedPresence = false;

    // Reset timers if they are already running
    timer?.cancel();
    backgroundSyncTimer?.cancel();

    startTimer();
    startBackgroundSync();
  }

  static Future<void> checkExistingQueue() async {
    if (currentUserId.isEmpty || isQueueActive.value) return;

    try {
      final ticket = await _queue.latestTicketFor(currentUserId);

      if (ticket != null) {
        QueueStatus scrStatus = ticket.screeningStatus;
        QueueStatus conStatus = ticket.consultStatus;

        if (scrStatus == QueueStatus.completed &&
            conStatus == QueueStatus.completed) {
          return;
        }

        DateTime? createdAt = ticket.createdAt;
        if (createdAt == null) return;
        DateTime now = DateTime.now();

        // Check if the queue was created today; if not, ignore it
        if (createdAt.year != now.year ||
            createdAt.month != now.month ||
            createdAt.day != now.day) {
          return;
        }

        myQueueNumber = ticket.id.toString();
        isQueueActive.value = true;
        hasConfirmedPresence = false;

        if (scrStatus != QueueStatus.completed) {
          queueStage.value = 'Screening';
          int ewtFromDb = ticket.screeningEwt;

          int passedSeconds = now.difference(createdAt).inSeconds;
          if (passedSeconds < 0) {
            passedSeconds = 0;
          }
          startSeconds = ewtFromDb * 60;
          int leftover = startSeconds - passedSeconds;
          remainingSeconds.value = leftover > 0 ? leftover : 0;

          if (scrStatus == QueueStatus.inProgress) {
            patientStatusText.value =
                'It is your turn! Please proceed to the Screening room.';
          } else {
            patientStatusText.value = 'Waiting for Screening...';
          }
        } else if (conStatus != QueueStatus.completed) {
          queueStage.value = 'Consultation';
          int ewtFromDb = ticket.doctorEwt;

          DateTime screenDoneAt = ticket.screeningCompletedAt ?? now;

          int passedSeconds = now.difference(screenDoneAt).inSeconds;
          if (passedSeconds < 0) {
            passedSeconds = 0;
          }
          startSeconds = ewtFromDb * 60;
          int leftover = startSeconds - passedSeconds;
          remainingSeconds.value = leftover > 0 ? leftover : 0;

          if (conStatus == QueueStatus.inProgress) {
            patientStatusText.value =
                'It is your turn! Please proceed to the Doctor\'s room.';
          } else {
            patientStatusText.value =
                'Screening completed. Now queueing for consultation.';
          }
        }

        startTimer();
        startBackgroundSync();
      }
    } catch (e) {
      debugPrint("Fail to restore old ticket: $e");
    }
  }

  static Future<void> _syncPatientsAhead() async {
    try {
      if (isQueueActive.value &&
          myQueueNumber != '-' &&
          !myQueueNumber.contains('SKIP')) {
        // Use a local copy of myQueueNumber to avoid race conditions
        String checkingQueueId = myQueueNumber;

        final myRecord = await _queue.ticketById(int.parse(checkingQueueId));

        // If the queue number has changed since the last check, skip this sync
        if (checkingQueueId != myQueueNumber) return;

        if (myRecord != null) {
          QueueStatus currentScreeningStatus = myRecord.screeningStatus;
          QueueStatus currentConsultStatus = myRecord.consultStatus;

          if (currentScreeningStatus == QueueStatus.noShow ||
              currentConsultStatus == QueueStatus.noShow) {
            isQueueActive.value = false;
            timer?.cancel();
            myQueueNumber = "SKIPPED (No Show)";
            patientStatusText.value = 'You missed your turn.';

            // ==========================================
            // LATEST CODE: NOTIFICATION FOR NO SHOW
            // ==========================================
            addNotification(
              title: 'Turn Skipped (No Show)',
              message:
                  'Your queue number was skipped because you did not confirm your presence. Please request a new ticket.',
              requiresAction: false,
            );
            // ==========================================
            return;
          }

          if (queueStage.value == 'Screening') {
            if (currentScreeningStatus == QueueStatus.inProgress) {
              patientStatusText.value =
                  'It is your turn! Please proceed to the Screening room.';
            } else if (currentScreeningStatus == QueueStatus.completed) {
              queueStage.value = 'Consultation';
              patientStatusText.value =
                  'Screening completed. Now queueing for consultation.';
              startSeconds = myRecord.doctorEwt * 60;
              remainingSeconds.value = startSeconds;
              hasConfirmedPresence = false;
            }
          } else if (queueStage.value == 'Consultation') {
            if (currentConsultStatus == QueueStatus.inProgress) {
              patientStatusText.value =
                  'It is your turn! Please proceed to the Doctor\'s room.';
            } else if (currentConsultStatus == QueueStatus.completed) {
              isQueueActive.value = false;
              timer?.cancel();
              patientStatusText.value =
                  'All procedures completed. Get well soon!';
              return;
            }
          }

          int dbEwt = myRecord.ewtFor(
            consultation: queueStage.value != 'Screening',
          );
          int dbSeconds = dbEwt * 60;

          // LATEST CODE: ONLY UPDATE IF HOSPITAL STAFF CHANGES THE TIME (RESET)
          // =================================================================
          if (dbSeconds != startSeconds) {
            int difference = dbSeconds - startSeconds;
            remainingSeconds.value += difference;

            if (remainingSeconds.value < 0) {
              remainingSeconds.value = 0;
            }

            startSeconds =
                dbSeconds; // Update the startSeconds to the new value

            if (difference > 0) {
              addNotification(
                title: "Wait Time Updated",
                message:
                    "The staff has added more time to the queue due to unexpected delays. Please be patient.",
                requiresAction: false,
              );
            } else {
              addNotification(
                title: "Queue Moving Fast!",
                message:
                    "The patient ahead finished early! Your waiting time has been reduced.",
                requiresAction: false,
              );
            }
          }

          patientsAhead.value = await _queue.countWaitingAhead(
            consultation: queueStage.value != 'Screening',
            ticketId: int.parse(myQueueNumber),
          );
        }
      } else {
        patientsAhead.value = await _queue.countWaitingForScreening();
      }
    } catch (e) {
      debugPrint("Fail to sync queue Supabase: $e");
    }
  }

  // FUNCTION TO FORCE SYNC
  static Future<void> forceSync() async {
    await _syncPatientsAhead();
  }

  static void startBackgroundSync() {
    if (backgroundSyncTimer != null && backgroundSyncTimer!.isActive) return;
    _syncPatientsAhead();
    backgroundSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _syncPatientsAhead();
    });
  }

  static void startTimer() {
    if (timer != null && timer!.isActive) return;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _tickCount++;
      if (_tickCount % 10 == 0 && isQueueActive.value) {
        _syncPatientsAhead();
      }
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
        if (remainingSeconds.value <= 180 &&
            remainingSeconds.value > 0 &&
            !hasConfirmedPresence &&
            !showCheckInDialog.value) {
          // LATEST CODE: SHOW CHECK-IN DIALOG AND NOTIFICATION WHEN 3 MINUTES LEFT
          showCheckInDialog.value = true;
          addNotification(
            title: 'Your Turn is Near!',
            message:
                'Only 3 minutes left until your turn. Please confirm your presence.',
            requiresAction: true,
          );
          startAutoSkipCountdown();
        }
      }
    });
  }

  static void startAutoSkipCountdown() {
    autoSkipTimer?.cancel();

    // LATEST CODE: AUTO SKIP COUNTDOWN (3 MINUTES)
    int skipSeconds = 180;

    autoSkipTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (skipSeconds > 0) {
        skipSeconds--;
      } else {
        t.cancel();

        // LATEST CODE: AUTO SKIP THE QUEUE IF NOT CONFIRMED
        try {
          if (myQueueNumber != '-' && !myQueueNumber.contains('SKIP')) {
            await _queue.markNoShow(
              int.parse(myQueueNumber),
              consultation: queueStage.value != 'Screening',
            );
          }
        } catch (e) {
          debugPrint("Error performing auto-skip: $e");
        }

        isQueueActive.value = false;
        showCheckInDialog.value = false;
      }
    });
  }

  static Future<void> confirmPresence() async {
    // 1. Update the database to mark the patient as present
    try {
      if (myQueueNumber != '-' && !myQueueNumber.contains('SKIP')) {
        await _queue.confirmPresence(int.parse(myQueueNumber));
      }
    } catch (e) {
      debugPrint("Failed to update presence: $e");
    }

    hasConfirmedPresence = true;
    showCheckInDialog.value = false;
    autoSkipTimer?.cancel();

    final list = List<Map<String, dynamic>>.from(myNotifications.value);
    for (var n in list) {
      if (n['requiresAction'] == true && n['isActioned'] == false) {
        n['isActioned'] = true;
        n['isRead'] = true;
      }
    }
    myNotifications.value = list;
  }

  static void markAsRead(String id) {
    final list = List<Map<String, dynamic>>.from(myNotifications.value);
    final index = list.indexWhere((n) => n['id'] == id);
    if (index != -1) {
      list[index]['isRead'] = true;
      myNotifications.value = list;
    }
  }
}

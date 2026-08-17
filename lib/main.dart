import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID'] ?? '');
  OneSignal.Notifications.requestPermission(true);

  runApp(const MyApp());
}

class AppLang {
  static ValueNotifier<String> current = ValueNotifier('English');

  static const Map<String, Map<String, String>> _dict = {
    'English': {
      'settings': 'Settings',
      'account': 'Account',
      'change_pass': 'Change Password',
      'privacy': 'Privacy Settings',
      'notif': 'Notifications',
      'queue_alert': 'Queue Push Alerts',
      'email_alert': 'Email Notifications',
      'general': 'General',
      'language': 'Language',
      'dark_mode': 'Dark Mode',
      'about': 'About',
      'tnc': 'Terms & Conditions',
      'app_version': 'App Version',
      'personal_info': 'Personal Info',
      'medical_history': 'Medical History',
      'appointment_records': 'Appointment Records',
      'help_support': 'Help & Support',
      'logout': 'Log Out',
      'my_queue': 'My Queue No.',
      'patients_ahead': 'Patients Ahead',
      'patient_overview': 'Patient Overview',
    },
    'Bahasa Melayu': {
      'settings': 'Tetapan',
      'account': 'Akaun',
      'change_pass': 'Tukar Kata Laluan',
      'privacy': 'Tetapan Privasi',
      'notif': 'Notifikasi',
      'queue_alert': 'Amaran Giliran',
      'email_alert': 'Notifikasi Emel',
      'general': 'Umum',
      'language': 'Bahasa',
      'dark_mode': 'Mod Gelap',
      'about': 'Tentang',
      'tnc': 'Terma & Syarat',
      'app_version': 'Versi Aplikasi',
      'personal_info': 'Maklumat Peribadi',
      'medical_history': 'Sejarah Perubatan',
      'appointment_records': 'Rekod Temu Janji',
      'help_support': 'Bantuan & Sokongan',
      'logout': 'Log Keluar',
      'my_queue': 'No. Giliran Saya',
      'patients_ahead': 'Pesakit Di Hadapan',
      'patient_overview': 'Tinjauan Pesakit',
    },
    '中文 (Mandarin)': {
      'settings': '设置',
      'account': '账户',
      'change_pass': '更改密码',
      'privacy': '隐私设置',
      'notif': '通知',
      'queue_alert': '排队警报',
      'email_alert': '电子邮件通知',
      'general': '常规',
      'language': '语言',
      'dark_mode': '深色模式',
      'about': '关于',
      'tnc': '条款和条件',
      'app_version': '应用版本',
      'personal_info': '个人信息',
      'medical_history': '病史',
      'appointment_records': '预约记录',
      'help_support': '帮助与支持',
      'logout': '登出',
      'my_queue': '我的排队号',
      'patients_ahead': '前方患者',
      'patient_overview': '患者概览',
    },
  };

  static String t(String key) {
    return _dict[current.value]?[key] ?? _dict['English']?[key] ?? key;
  }
}

// =========================================================================
// 2. THEME (DARK / LIGHT MODE)
// =========================================================================
class AppTheme {
  static ValueNotifier<bool> isDark = ValueNotifier(true);

  static Color get textPrimary =>
      isDark.value ? Colors.white : const Color(0xFF1E1E24);
  static Color get textSecondary =>
      isDark.value ? Colors.white70 : Colors.black54;
  static Color get textMuted => isDark.value ? Colors.white54 : Colors.black38;

  static Color get glassBg => isDark.value
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.white.withValues(alpha: 0.4);
  static Color get glassBorder => isDark.value
      ? Colors.white.withValues(alpha: 0.15)
      : Colors.black.withValues(alpha: 0.1);
  static Color get avatarBg => isDark.value ? Colors.white24 : Colors.black12;
  static Color get dividerColor =>
      isDark.value ? Colors.white24 : Colors.black12;

  static List<Color> get bgGradient => isDark.value
      ? const [
          Color(0xFF101014),
          Color(0xFF101014),
          Color(0xFF2A161C),
          Color(0xFFD46A84),
        ]
      : const [
          Color(0xFFF5F7FA),
          Color(0xFFE4E9F2),
          Color(0xFFFDE4EC),
          Color(0xFFF48FB1),
        ];
}

// =========================================================================
// 2.5 GLOBAL MEMORY (To ensure data doesn't get lost when switching screens)
// =========================================================================
class QueueData {
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
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('hospital_queue')
          .select()
          .eq('patient_id', currentUserId)
          .neq('screening_status', 'No Show')
          .neq('consult_status', 'No Show')
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        String scrStatus = response['screening_status'] ?? '';
        String conStatus = response['consult_status'] ?? '';

        if (scrStatus == 'Completed' && conStatus == 'Completed') {
          return;
        }

        DateTime createdAt = DateTime.parse(response['created_at']).toLocal();
        DateTime now = DateTime.now();

        // Check if the queue was created today; if not, ignore it
        if (createdAt.year != now.year ||
            createdAt.month != now.month ||
            createdAt.day != now.day) {
          return;
        }

        myQueueNumber = response['id'].toString();
        isQueueActive.value = true;
        hasConfirmedPresence = false;

        if (scrStatus != 'Completed') {
          queueStage.value = 'Screening';
          int ewtFromDb = response['screening_ewt'] ?? 0;

          int passedSeconds = now.difference(createdAt).inSeconds;
          if (passedSeconds < 0) {
            passedSeconds = 0;
          }
          startSeconds = ewtFromDb * 60;
          int leftover = startSeconds - passedSeconds;
          remainingSeconds.value = leftover > 0 ? leftover : 0;

          if (scrStatus == 'In Progress') {
            patientStatusText.value =
                'It is your turn! Please proceed to the Screening room.';
          } else {
            patientStatusText.value = 'Waiting for Screening...';
          }
        } else if (conStatus != 'Completed') {
          queueStage.value = 'Consultation';
          int ewtFromDb = response['doctor_ewt'] ?? 0;

          DateTime screenDoneAt = response['screening_completed_at'] != null
              ? DateTime.parse(response['screening_completed_at']).toLocal()
              : now;

          int passedSeconds = now.difference(screenDoneAt).inSeconds;
          if (passedSeconds < 0) {
            passedSeconds = 0;
          }
          startSeconds = ewtFromDb * 60;
          int leftover = startSeconds - passedSeconds;
          remainingSeconds.value = leftover > 0 ? leftover : 0;

          if (conStatus == 'In Progress') {
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
      final supabase = Supabase.instance.client;

      if (isQueueActive.value &&
          myQueueNumber != '-' &&
          !myQueueNumber.contains('SKIP')) {
        // Use a local copy of myQueueNumber to avoid race conditions
        String checkingQueueId = myQueueNumber;

        final myRecord = await supabase
            .from('hospital_queue')
            .select()
            .eq('id', int.parse(checkingQueueId))
            .maybeSingle();

        // If the queue number has changed since the last check, skip this sync
        if (checkingQueueId != myQueueNumber) return;

        if (myRecord != null) {
          String currentScreeningStatus = myRecord['screening_status'] ?? '';
          String currentConsultStatus = myRecord['consult_status'] ?? '';

          if (currentScreeningStatus == 'No Show' ||
              currentConsultStatus == 'No Show') {
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
            if (currentScreeningStatus == 'In Progress') {
              patientStatusText.value =
                  'It is your turn! Please proceed to the Screening room.';
            } else if (currentScreeningStatus == 'Completed') {
              queueStage.value = 'Consultation';
              patientStatusText.value =
                  'Screening completed. Now queueing for consultation.';
              startSeconds = (myRecord['doctor_ewt'] as int) * 60;
              remainingSeconds.value = startSeconds;
              hasConfirmedPresence = false;
            }
          } else if (queueStage.value == 'Consultation') {
            if (currentConsultStatus == 'In Progress') {
              patientStatusText.value =
                  'It is your turn! Please proceed to the Doctor\'s room.';
            } else if (currentConsultStatus == 'Completed') {
              isQueueActive.value = false;
              timer?.cancel();
              patientStatusText.value =
                  'All procedures completed. Get well soon!';
              return;
            }
          }

          int dbEwt = queueStage.value == 'Screening'
              ? myRecord['screening_ewt']
              : myRecord['doctor_ewt'];
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

          final countResponse = await supabase
              .from('hospital_queue')
              .select('id')
              .eq(
                queueStage.value == 'Screening'
                    ? 'screening_status'
                    : 'consult_status',
                'Waiting',
              )
              .lt('id', int.parse(myQueueNumber));

          patientsAhead.value = countResponse.length;
        }
      } else {
        final countResponse = await supabase
            .from('hospital_queue')
            .select('id')
            .eq('screening_status', 'Waiting');
        patientsAhead.value = countResponse.length;
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
        final supabase = Supabase.instance.client;
        String statusField = queueStage.value == 'Screening'
            ? 'screening_status'
            : 'consult_status';

        try {
          if (myQueueNumber != '-' && !myQueueNumber.contains('SKIP')) {
            await supabase
                .from('hospital_queue')
                .update({statusField: 'No Show'})
                .eq('id', int.parse(myQueueNumber));
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
        final supabase = Supabase.instance.client;
        await supabase
            .from('hospital_queue')
            .update({'is_present': true})
            .eq('id', int.parse(myQueueNumber));
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

// =========================================================================
// 3. MAIN APP WIDGET
// =========================================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.isDark,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLang.current,
          builder: (context, lang, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Q-Health App',
              theme: ThemeData(
                primarySwatch: Colors.pink,
                scaffoldBackgroundColor: isDark ? Colors.black : Colors.white,
              ),
              home: const LoginScreen(),
            );
          },
        );
      },
    );
  }
}

// =========================================================================
// 4. APP BASE SCREEN
// =========================================================================
class AppBaseScreen extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavBar;

  const AppBaseScreen({super.key, required this.body, this.bottomNavBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.isDark.value ? Colors.black : Colors.white,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppTheme.bgGradient,
                stops: const [0.0, 0.6, 0.85, 1.0],
              ),
            ),
          ),
          body,
          if (bottomNavBar != null)
            Positioned(bottom: 20, left: 20, right: 20, child: bottomNavBar!),
        ],
      ),
    );
  }
}

Widget _buildCustomTextField({
  required IconData icon,
  required String hintText,
  required bool obscureText,
  TextEditingController? controller,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppTheme.glassBg,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppTheme.glassBorder),
    ),
    child: TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.textMuted),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 20,
        ),
      ),
    ),
  );
}

Widget _buildOrDivider() {
  return Row(
    children: [
      Expanded(child: Container(height: 1, color: AppTheme.dividerColor)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          'Or',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ),
      Expanded(child: Container(height: 1, color: AppTheme.dividerColor)),
    ],
  );
}

// =========================================================================
// 5. LOGIN SCREEN FOR PATIENT
// =========================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true; // EYE ICON FOR PASSWORD FIELD

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Load saved credentials on init

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        final user = session.user;
        final supabase = Supabase.instance.client;

        final patientRecord = await supabase
            .from('patients')
            .select()
            .eq('email', user.email ?? '')
            .maybeSingle();

        if (patientRecord == null) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CompleteProfileScreen(
                  email: user.email ?? '',
                  fullName: user.userMetadata?['full_name'] ?? 'New Patient',
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            QueueData.currentUserId = patientRecord['id'].toString();
            QueueData.currentUserName = patientRecord['full_name'] ?? 'Patient';

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login Successful via Google!'),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      }
    });
  }

  // ==========================================
  // LATEST CODE: READ SAVED CREDENTIALS
  // ==========================================
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('remember_username');
    final savedPassword = prefs.getString('remember_password');
    final isRemembered = prefs.getBool('remember_me') ?? false;

    if (isRemembered && savedUsername != null && savedPassword != null) {
      setState(() {
        _usernameController.text = savedUsername;
        _passwordController.text = savedPassword;
        _rememberMe = isRemembered;
      });
    }
  }

  Future<void> _loginUser() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Username and Password!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final user = await supabase
          .from('patients')
          .select()
          .eq('username', _usernameController.text)
          .maybeSingle();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Username does not exist. Please register an account.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (user['password'] != _passwordController.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect password! Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setString(
              'remember_username',
              _usernameController.text,
            );
            await prefs.setString(
              'remember_password',
              _passwordController.text,
            );
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('remember_username');
            await prefs.remove('remember_password');
            await prefs.setBool('remember_me', false);
          }

          QueueData.currentUserId = user['id'].toString();
          String firstName = user['first_name'] ?? '';
          String lastName = user['last_name'] ?? '';
          String displayName = (firstName.isNotEmpty || lastName.isNotEmpty)
              ? '$firstName $lastName'.trim()
              : (user['full_name'] ?? 'Patient');
          QueueData.currentUserName = displayName;

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login Successful!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 350,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.glassBg,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    _buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'Username',
                      obscureText: false,
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 20),

                    // LATEST CODE: PASSWORD FIELD WITH EYE ICON
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.glassBg,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 20,
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ==========================================
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (bool? newValue) {
                              setState(() {
                                _rememberMe = newValue!;
                              });
                            },
                            activeColor: Colors.pinkAccent,
                            checkColor: Colors.white,
                            side: BorderSide(color: AppTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember Me',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 35),
                    GestureDetector(
                      onTap: _isLoading ? null : _loginUser,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.glassBg,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppTheme.glassBorder,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.pinkAccent,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Sign In',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildOrDivider(),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await Supabase.instance.client.auth.signInWithOAuth(
                            OAuthProvider.google,
                            redirectTo: 'io.supabase.qhealth://login-callback',
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Google Sign-In Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: AppTheme.glassBg,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppTheme.glassBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 15),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Register",
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'forgot password?',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(height: 1, color: AppTheme.dividerColor),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StaffLoginScreen(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.health_and_safety,
                            color: Colors.teal,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Healthcare Provider? ",
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            "Staff Portal",
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 6. REGISTER SCREEN FOR NEW PATIENT & FORGET PASSWORD
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _icController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _registerUser() async {
    if (_usernameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _fullNameController.text.isEmpty ||
        _icController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all important information!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('patients').insert({
        'username': _usernameController.text,
        'password': _passwordController.text,
        'full_name': _fullNameController.text,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'ic_number': _icController.text,
        'phone': _phoneController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration Successful! Please Login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _icController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 350,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.glassBg,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    _buildCustomTextField(
                      icon: Icons.alternate_email,
                      hintText: 'Username',
                      obscureText: false,
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 15),
                    _buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'Full Name(as per IC)',
                      obscureText: false,
                      controller: _fullNameController,
                    ),
                    const SizedBox(
                      height: 15,
                    ), // DISTANCE BETWEEN FULL NAME AND FIRST NAME
                    _buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'First Name',
                      obscureText: false,
                      controller: _firstNameController,
                    ),
                    const SizedBox(
                      height: 15,
                    ), // DISTANCE BETWEEN FIRST NAME AND LAST NAME
                    _buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'Last Name',
                      obscureText: false,
                      controller: _lastNameController,
                    ),
                    const SizedBox(height: 15),
                    _buildCustomTextField(
                      icon: Icons.mail_outline,
                      hintText: 'Email Address',
                      obscureText: false,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 15),
                    _buildCustomTextField(
                      icon: Icons.badge_outlined,
                      hintText: 'IC Number',
                      obscureText: false,
                      controller: _icController,
                    ),
                    const SizedBox(height: 15),
                    _buildCustomTextField(
                      icon: Icons.phone_outlined,
                      hintText: 'Phone Number',
                      obscureText: false,
                      controller: _phoneController,
                    ),
                    const SizedBox(height: 15),
                    _buildCustomTextField(
                      icon: Icons.lock_outline,
                      hintText: 'Password',
                      obscureText: true,
                      controller: _passwordController,
                    ),
                    const SizedBox(height: 35),

                    GestureDetector(
                      onTap: _isLoading ? null : _registerUser,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.glassBg,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppTheme.glassBorder,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.pinkAccent,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Create Account',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildOrDivider(),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: AppTheme.glassBg,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppTheme.glassBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 15),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Login",
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
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
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 350,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.glassBg,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Forgot Password',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter your email address and we will send you a link to reset your password.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    _buildCustomTextField(
                      icon: Icons.mail_outline,
                      hintText: 'Email Address',
                      obscureText: false,
                    ),
                    const SizedBox(height: 35),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reset link sent to your email'),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.glassBg,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppTheme.glassBorder,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Send Reset Link',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Remember your password? ",
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Login",
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
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
        ),
      ),
    );
  }
}

// 7. DASHBOARD (Home)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _liveQueueOverview = [];
  Timer? _overviewFetchTimer;
  Timer? _overviewTickTimer;

  bool _hasShownTurnDialog = false;

  late PageController _pageController;
  late VideoPlayerController _videoController;
  int _activePage = 0;
  Timer? _adTimer;
  bool _isVideoEndReached = false;

  final List<Map<String, String>> _kkmImageAds = [
    {
      'image': 'assets/images/Heatwave.jpg',
      'url':
          'https://www.thestar.com.my/news/nation/2026/03/26/schools-told-to-prepare-for-hot-weather',
      'title': 'Schools Advised to Prepare for Extreme Hot Weather',
    },
    {
      'image': 'assets/images/Virus.jpg',
      'url':
          'https://www.moh.gov.my/images/kenyataan-media/2026/FEB%202026/23022026%20Kenyataan%20Media%20Pemantauan%20Risiko%20Jangkitan%20Virus%20Nipah%20Di%20Malaysia%202322026.pdf',
      'title': 'Nipah Virus Infection Risk Monitoring in Malaysia',
    },
    {
      'image': 'assets/images/gemini.jpg',
      'url':
          'https://www.freemalaysiatoday.com/category/bahasa/tempatan/2026/04/10/bekalan-ubat-stabil-sekurang-kurangnya-hingga-hujung-jun',
      'title': 'Medicine Supply Remains Stable At Least Until End of June',
    },
    {
      'image': 'assets/images/gemini haji.jpg',
      'url':
          'https://www.freemalaysiatoday.com/category/bahasa/tempatan/2025/10/23/bakal-jemaah-haji-gagal-ujian-kesihatan-boleh-mohon-semula-tahun-depan',
      'title': 'Prospective Hajj Pilgrims Failing Health Tests Can Reapply',
    },
    {
      'image': 'assets/images/astro.jpg',
      'url':
          'https://www.astroawani.com/video/kkm-pantau-rapi-perkembangan-penularan-hantavirus-0',
      'title': 'MOH Closely Monitoring the Spread of Hantavirus',
    },
    {
      'image': 'assets/images/AI.jpg',
      'url':
          'https://www.astroawani.com/video/video-terkini-x7sio1/kkm-komited-perkasa-ai-analitik-data-dalam-sistem-kesihatan-negara-x9mk1nk',
      'title':
          'MOH Committed to Empowering AI and Data Analytics in Healthcare',
    },
    {'image': 'assets/images/kkm.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);

    // 1. SETUP VIDEO PLAYER
    _videoController = VideoPlayerController.asset('assets/videos/intro.mp4')
      ..initialize()
          .then((_) {
            setState(() {});
            _videoController.play();
          })
          .catchError((error) {
            debugPrint("Error loading video: $error");
          });

    // 2. LISTENER VIDEO
    _videoController.addListener(() {
      if (!_videoController.value.isInitialized ||
          _videoController.value.duration == Duration.zero) {
        return;
      }

      final position = _videoController.value.position;
      final duration = _videoController.value.duration;

      if (position >= duration - const Duration(milliseconds: 200) &&
          !_isVideoEndReached &&
          _activePage == 0) {
        _isVideoEndReached = true;
        _moveToNextPage();
      }
    });

    // 3. SETUP QUEUE SYNC & LIVE OVERVIEW
    QueueData.checkExistingQueue().then((_) {
      QueueData.startBackgroundSync();
      QueueData.startTimer();
    });
    QueueData.showCheckInDialog.addListener(_presenceListener);

    QueueData.patientStatusText.addListener(() {
      String currentText = QueueData.patientStatusText.value;

      if (currentText.contains("It is your turn!") && !_hasShownTurnDialog) {
        _hasShownTurnDialog = true;
        if (mounted) {
          _showTurnDialog();
        }
      } else if (!currentText.contains("It is your turn!")) {
        _hasShownTurnDialog = false;
      }
    });

    // LATEST CODE : CHECK FOR POPUPS AFTER WIDGETS ARE BUILT
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. CHECK IF PRESENCE CONFIRMATION DIALOG SHOULD BE SHOWN
      if (QueueData.showCheckInDialog.value &&
          !QueueData.hasConfirmedPresence) {
        _showPresenceDialog();
      }

      // 2. CHECK IF TURN DIALOG SHOULD BE SHOWN
      if (QueueData.patientStatusText.value.contains("It is your turn!") &&
          !_hasShownTurnDialog) {
        _hasShownTurnDialog = true;
        if (mounted) {
          _showTurnDialog();
        }
      }
    });
    // =================================================================

    _fetchLiveQueueOverview();
    _overviewFetchTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) => _fetchLiveQueueOverview(),
    );
    _overviewTickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _liveQueueOverview.isNotEmpty) {
        setState(() {
          for (var p in _liveQueueOverview) {
            if (p['seconds'] > 0) p['seconds']--;
          }
        });
      }
    });
  }

  Future<void> _openExternalLink(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  void _moveToNextPage() {
    if (_pageController.hasClients) {
      int next = (_activePage + 1) % (_kkmImageAds.length + 1);
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handlePageChange(int index) {
    setState(() {
      _activePage = index;
    });

    _adTimer?.cancel();

    if (index == 0) {
      _isVideoEndReached = false;
      _videoController.seekTo(Duration.zero).then((_) {
        _videoController.play();
      });
    } else {
      _videoController.pause();
      _adTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _moveToNextPage();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (QueueData.isQueueActive.value) {
        QueueData.forceSync();
        _fetchLiveQueueOverview();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adTimer?.cancel();

    if (_videoController.value.isPlaying) {
      _videoController.pause();
    }

    _videoController.dispose();
    _pageController.dispose();
    _overviewFetchTimer?.cancel();
    _overviewTickTimer?.cancel();
    QueueData.showCheckInDialog.removeListener(_presenceListener);
    super.dispose();
  }

  void _presenceListener() {
    if (QueueData.showCheckInDialog.value) _showPresenceDialog();
  }

  void _showPresenceDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 20.0,
                  left: 20.0,
                  right: 20.0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: AppTheme.glassBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Your Turn is Near!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Only 3 minutes left until your turn. Please confirm your presence in the waiting area now",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  QueueData.confirmPresence();
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Presence confirmed. Please wait for your name to be called.",
                                    ),
                                    backgroundColor: Colors.teal,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 5,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              child: const Text(
                                "I'm Here",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  // 8. POPUP DIALOG FOR PATIENT TURN NOTIFICATION
  void _showTurnDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 20.0,
                  left: 20.0,
                  right: 20.0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: AppTheme.glassBg,
                        borderRadius: BorderRadius.circular(20),

                        border: Border.all(color: Colors.transparent),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "It's Your Turn!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Please proceed to the ${QueueData.queueStage.value} room immediately.",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  QueueData.remainingSeconds.value = 0;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 5,
                              ),
                              child: const Text(
                                "Proceed",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  String _getFormattedTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  String _formatOverviewTime(int totalSeconds) {
    if (totalSeconds <= 0) return "00:00";
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchLiveQueueOverview() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('hospital_queue')
          .select('*, patients(first_name, last_name, full_name)')
          .neq('screening_status', 'No Show')
          .neq('consult_status', 'No Show')
          .order('id', ascending: true);

      List<Map<String, dynamic>> newList = [];
      String currentStage = QueueData.isQueueActive.value
          ? QueueData.queueStage.value
          : 'Screening';
      DateTime now = DateTime.now();

      for (var record in response) {
        String scrStatus = record['screening_status'] ?? '';
        String conStatus = record['consult_status'] ?? '';

        bool isValid = false;
        String currentStatus = '';

        if (currentStage == 'Screening' &&
            (scrStatus == 'Waiting' || scrStatus == 'In Progress')) {
          isValid = true;
          currentStatus = scrStatus;
        } else if (currentStage == 'Consultation' &&
            (conStatus == 'Waiting' || conStatus == 'In Progress')) {
          isValid = true;
          currentStatus = conStatus;
        }

        if (!isValid) continue;

        String pName = 'Unknown Patient';
        if (record['patients'] != null && record['patients'] is Map) {
          String fName = record['patients']['first_name'] ?? '';
          String lName = record['patients']['last_name'] ?? '';
          String fullName = record['patients']['full_name'] ?? '';

          if (fName.isNotEmpty || lName.isNotEmpty) {
            pName = '$fName $lName'.trim();
          } else {
            pName = fullName;
          }
        }

        int ewtMins = currentStage == 'Screening'
            ? (record['screening_ewt'] ?? 0)
            : (record['doctor_ewt'] ?? 0);
        int startSecs = ewtMins * 60;

        // LATEST CODE : SYNC TIMER LOGIC
        int remaining;

        // 1. IF CURRENT USER, USE THE SYNCED TIMER VALUE (NO NEGATIVE TIME)
        if (record['patient_id'].toString() == QueueData.currentUserId) {
          remaining = QueueData.remainingSeconds.value;
        }
        // 2. IF NOT CURRENT USER, CALCULATE BASED ON TIMESTAMP
        else {
          DateTime startTime = currentStage == 'Screening'
              ? DateTime.parse(record['created_at']).toLocal()
              : (record['screening_completed_at'] != null
                    ? DateTime.parse(record['screening_completed_at']).toLocal()
                    : now);

          int passedSecs = now.difference(startTime).inSeconds;
          if (passedSecs < 0) passedSecs = 0;

          remaining = startSecs - passedSecs;
          if (remaining < 0) remaining = 0;
        }

        newList.add({
          'id': record['id'].toString(),
          'name': pName,
          'isMe': record['patient_id'].toString() == QueueData.currentUserId,
          'seconds': remaining,
          'status': currentStatus,
        });
      }

      if (mounted) {
        setState(() {
          _liveQueueOverview = newList;
        });
      }
    } catch (e) {
      debugPrint("Gagal fetch patient overview: $e");
    }
  }

  // ---WIDGET BUILDERS---
  Widget _buildDynamicKkmTopBar(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double bannerHeight = screenWidth > 600 ? 320 : 190;

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Container(
        height: bannerHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.glassBg,
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: _handlePageChange,
              itemCount: _kkmImageAds.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _videoController.value.isInitialized
                      ? SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoController.value.size.width,
                              height: _videoController.value.size.height,
                              child: VideoPlayer(_videoController),
                            ),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Colors.pinkAccent,
                          ),
                        );
                } else {
                  // CLICKABLE LOCAL IMAGE SLOT
                  final adData = _kkmImageAds[index - 1];
                  return GestureDetector(
                    onTap: () {
                      if (adData['url'] != null) {
                        _openExternalLink(adData['url']!);
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. ORIGINAL BACKGROUND IMAGE
                        Image.asset(
                          adData['image']!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.white24,
                                size: 50,
                              ),
                            );
                          },
                        ),

                        // 2. BOTTOM HALF GRADIENT OVERLAY (Fades smoothly upwards to reveal background)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 110, // Height of the gradient area
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(
                                    alpha: 0.8,
                                  ), // Darker base for clear text readability
                                  Colors.black.withValues(
                                    alpha: 0.35,
                                  ), // Smooth fading mid-point
                                  Colors
                                      .transparent, // Completely blends into the background image
                                ],
                                stops: const [
                                  0.0,
                                  0.5,
                                  1.0,
                                ], // Controls where the fading effect starts
                              ),
                            ),
                          ),
                        ),

                        // 3. CLEAN NEWS HEADLINE AND ARROW ICON (No pink badge)
                        Positioned(
                          bottom:
                              22, // Adjusted padding to align with dot indicators
                          left: 15,
                          right: 15,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  adData['title'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 4.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),

            // INDICATOR DOTS
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _kkmImageAds.length + 1,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 5,
                    width: _activePage == i ? 18 : 5,
                    decoration: BoxDecoration(
                      color: _activePage == i
                          ? Colors.tealAccent
                          : Colors.white30,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),

            // LABEL KKM INFO HUB
            Positioned(
              top: 15,
              left: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      "KKM Info Hub",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppTheme.glassBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello ${QueueData.currentUserName}!',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: QueueData.patientStatusText,
            builder: (context, txt, _) => Text(
              txt,
              style: const TextStyle(
                color: Colors.pinkAccent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleWaitTimeCard(int currentSeconds) {
    double progress = QueueData.startSeconds == 0
        ? 0
        : currentSeconds / QueueData.startSeconds;
    String titleText = 'Estimate Waiting Time :';
    String subtitleText =
        'Watch for a notification 3 minutes before your turn. You must confirm your arrival to avoid losing your spot in the queue.';

    if (currentSeconds <= 0) {
      if (QueueData.queueStage.value == 'Screening') {
        titleText = 'Screening Session';
        subtitleText =
            'You will automatically get estimation waiting time for consultation once you have complete screening session.';
      } else {
        titleText = 'Consultation Session';
        subtitleText =
            'Please proceed to the Doctor\'s room. Your consultation is ready.';
      }
    }

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 330,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppTheme.glassBg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: QueueData.queueStage,
                  builder: (context, stage, child) {
                    bool isScreening = stage == 'Screening';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(bottom: 25),
                      decoration: BoxDecoration(
                        color: Colors
                            .transparent, //Background become transparent, but border still visible
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: 0.5,
                          ), //border color with opacity
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        isScreening ? 'Screening Queue' : 'Consultation Queue',
                        style: const TextStyle(
                          color: Colors
                              .white, // Text color white for better visibility
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CustomPaint(
                          painter: _ProgressPainter(progress: progress),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getFormattedTime(currentSeconds),
                            style: const TextStyle(
                              color: Colors.pinkAccent,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  color: Colors.pinkAccent,
                                  blurRadius: 15.0,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            currentSeconds <= 0
                                ? (QueueData.queueStage.value == 'Screening'
                                      ? 'screening'
                                      : 'consultation')
                                : 'remaining',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  titleText,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientOverview() {
    if (_liveQueueOverview.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: AppTheme.glassBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: const Center(
          child: Text(
            "No patients currently in queue.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: _liveQueueOverview.map((patient) {
        bool isMe = patient['isMe'];
        int secs = patient['seconds'];
        String name = patient['name'];
        String initial = name.isNotEmpty
            ? name.substring(0, 1).toUpperCase()
            : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: AppTheme
                .glassBg, // Background color for the patient overview card
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme
                  .glassBorder, // Border color for the patient overview card
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    AppTheme.avatarBg, // Background color for the avatar
                child: Text(
                  initial,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow
                            .ellipsis, // Ensures that long names are truncated with an ellipsis
                        style: TextStyle(
                          color: AppTheme
                              .textPrimary, // Text color for the patient's name
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // If the patient is the current user, display a "You" badge next to their name
                    if (isMe)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          "You",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: secs <= 0
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: secs <= 0 ? Colors.green : Colors.orange,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  secs <= 0
                      ? (patient['status'] == 'In Progress'
                            ? 'In Room'
                            : '00:00')
                      : _formatOverviewTime(secs),
                  style: TextStyle(
                    color: secs <= 0 ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyQueueState(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 330,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppTheme.glassBg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.confirmation_num_outlined,
                  size: 80,
                  color: Colors.pinkAccent,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Get your queue number now",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You haven't requested a queue yet. Click the ticket icon below to start.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GetQueueScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Request Ticket",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      bottomNavBar: _buildGlassBottomNavBar(context, currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDynamicKkmTopBar(context),
              const SizedBox(height: 25),
              _buildGlassWelcomeCard(),
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: QueueData.isQueueActive,
                builder: (context, isActive, child) {
                  if (isActive) {
                    return ValueListenableBuilder<int>(
                      valueListenable: QueueData.remainingSeconds,
                      builder: (context, currentSeconds, child) {
                        return _buildGlassCircleWaitTimeCard(currentSeconds);
                      },
                    );
                  } else {
                    return _buildEmptyQueueState(context);
                  }
                },
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: _GlassStatCard(
                      icon: Icons.receipt_long,
                      title: AppLang.t('my_queue'),
                      value: QueueData.myQueueNumber,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: QueueData.patientsAhead,
                      builder: (context, aheadCount, child) {
                        return _GlassStatCard(
                          icon: Icons.people_outline,
                          title: AppLang.t('patients_ahead'),
                          value: aheadCount.toString(),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                AppLang.t('patient_overview'),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              _buildPatientOverview(),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _GlassStatCard({
    required this.icon,
    required this.title,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: Colors.pinkAccent, size: 28),
                  Text(
                    value,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  _ProgressPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final trackPaint = Paint()
      ..color = AppTheme.glassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, trackPaint);
    final sweepAngle = 2 * 3.141592653589793 * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (int i = 0; i < 3; i++) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6.0 + (i * 4)
        ..color = Colors.pinkAccent.withValues(alpha: 0.3 - (i * 0.1))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5.0 + (i * 5));
      canvas.drawArc(
        rect,
        -3.141592653589793 / 2,
        sweepAngle,
        false,
        glowPaint,
      );
    }
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0
      ..color = Colors.pinkAccent;
    canvas.drawArc(rect, -3.141592653589793 / 2, sweepAngle, false, corePaint);
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

Widget _buildGlassBottomNavBar(
  BuildContext context, {
  required int currentIndex,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(25),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.glassBg,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(
              Icons.dashboard,
              isSelected: currentIndex == 0,
              onTap: () {
                if (currentIndex != 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                }
              },
            ),
            _buildBottomNavItem(
              Icons.person_outline,
              isSelected: currentIndex == 1,
              onTap: () {
                if (currentIndex != 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                }
              },
            ),
            _buildBottomNavItem(
              Icons.confirmation_num_outlined,
              isSelected: currentIndex == 2,
              isQueue: true,
              onTap: () {
                if (currentIndex != 2) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GetQueueScreen(),
                    ),
                  );
                }
              },
            ),
            _buildBottomNavItem(
              Icons.notifications_none,
              isSelected: currentIndex == 3,
              onTap: () {
                if (currentIndex != 3) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                }
              },
            ),
            _buildBottomNavItem(
              Icons.auto_awesome,
              isSelected: currentIndex == 4,
              isAI: true,
              onTap: () {
                if (currentIndex != 4) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatbotScreen(),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildBottomNavItem(
  IconData icon, {
  bool isSelected = false,
  bool isAI = false,
  bool isQueue = false,
  required VoidCallback onTap,
}) {
  Color iconColor = AppTheme.textSecondary;
  if (isSelected) iconColor = AppTheme.textPrimary;
  if (isAI) iconColor = Colors.pinkAccent;

  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: isSelected
          ? BoxDecoration(color: AppTheme.avatarBg, shape: BoxShape.circle)
          : null,
      child: Icon(icon, color: iconColor, size: (isAI || isQueue) ? 28 : 24),
    ),
  );
}

// 8. PROFILE SCREEN
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      bottomNavBar: _buildGlassBottomNavBar(context, currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Icon(Icons.more_horiz, color: AppTheme.textPrimary),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4DB6AC), Color(0xFF00838F)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: AppTheme.glassBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.glassBorder,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.person,
                size: 70,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    _buildProfileMenuItem(
                      icon: Icons.person_outline,
                      title: AppLang.t('personal_info'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PersonalInfoScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 25),
                    _buildProfileMenuItem(
                      icon: Icons.medical_information_outlined,
                      title: AppLang.t('medical_history'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MedicalHistoryScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 25),
                    _buildProfileMenuItem(
                      icon: Icons.calendar_today_outlined,
                      title: AppLang.t('appointment_records'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AppointmentRecordsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 25),
                    _buildProfileMenuItem(
                      icon: Icons.settings_outlined,
                      title: AppLang.t('settings'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 25),
                    _buildProfileMenuItem(
                      icon: Icons.help_outline,
                      title: AppLang.t('help_support'),
                      onTap: () {},
                    ),
                    const SizedBox(height: 40),
                    _buildProfileMenuItem(
                      icon: Icons.logout,
                      title: AppLang.t('logout'),
                      isLogout: true,
                      onTap: () async {
                        await Supabase.instance.client.auth.signOut();
                        QueueData.clearData();

                        // 3. Kembali ke skrin Login
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: isLogout ? Colors.pinkAccent : AppTheme.textSecondary,
            size: 28,
          ),
          const SizedBox(width: 20),
          Text(
            title,
            style: TextStyle(
              color: isLogout ? Colors.pinkAccent : AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// 9. SETTINGS SCREEN
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailAlerts = false;

  final List<String> _availableLanguages = [
    'English',
    'Bahasa Melayu',
    '中文 (Mandarin)',
    'தமிழ் (Tamil)',
  ];

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.isDark.value
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.8),
                border: Border(
                  top: BorderSide(color: AppTheme.glassBorder, width: 1.0),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLang.t('language'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _availableLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = _availableLanguages[index];
                        final isSelected = AppLang.current.value == lang;
                        return ListTile(
                          title: Text(
                            lang,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.pinkAccent
                                  : AppTheme.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.pinkAccent,
                                )
                              : null,
                          onTap: () {
                            AppLang.current.value = lang;
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _togglePushNotifications(bool newValue) {
    if (!newValue) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
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
                      const SizedBox(height: 15),
                      Text(
                        'Disable Queue Alerts?',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'These alerts are crucial to notify you when it is your turn. If you turn them off, you might miss your appointment. Are you sure?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 25),
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
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pinkAccent.withValues(
                                  alpha: 0.8,
                                ),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _pushNotifications = false;
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Turn Off',
                                style: TextStyle(color: Colors.white),
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
    } else {
      setState(() {
        _pushNotifications = true;
      });
    }
  }

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
                    AppLang.t('settings'),
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
                    _buildSectionHeader(AppLang.t('account')),
                    _buildGlassContainer(
                      child: Column(
                        children: [
                          _buildSettingItem(
                            icon: Icons.lock_outline,
                            title: AppLang.t('change_pass'),
                            onTap: () {},
                          ),
                          Container(height: 1, color: AppTheme.dividerColor),
                          _buildSettingItem(
                            icon: Icons.privacy_tip_outlined,
                            title: AppLang.t('privacy'),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildSectionHeader(AppLang.t('notif')),
                    _buildGlassContainer(
                      child: Column(
                        children: [
                          _buildSettingSwitch(
                            icon: Icons.notifications_active_outlined,
                            title: AppLang.t('queue_alert'),
                            value: _pushNotifications,
                            onChanged: _togglePushNotifications,
                          ),
                          Container(height: 1, color: AppTheme.dividerColor),
                          _buildSettingSwitch(
                            icon: Icons.email_outlined,
                            title: AppLang.t('email_alert'),
                            value: _emailAlerts,
                            onChanged: (val) =>
                                setState(() => _emailAlerts = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildSectionHeader(AppLang.t('general')),
                    _buildGlassContainer(
                      child: Column(
                        children: [
                          _buildSettingItem(
                            icon: Icons.language,
                            title: AppLang.t('language'),
                            trailing: Text(
                              AppLang.current.value,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            onTap: () => _showLanguagePicker(context),
                          ),
                          Container(height: 1, color: AppTheme.dividerColor),
                          _buildSettingSwitch(
                            icon: Icons.dark_mode_outlined,
                            title: AppLang.t('dark_mode'),
                            value: AppTheme.isDark.value,
                            onChanged: (val) {
                              AppTheme.isDark.value = val;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildSectionHeader(AppLang.t('about')),
                    _buildGlassContainer(
                      child: Column(
                        children: [
                          _buildSettingItem(
                            icon: Icons.description_outlined,
                            title: AppLang.t('tnc'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TermsAndConditionsScreen(),
                                ),
                              );
                            },
                          ),
                          Container(height: 1, color: AppTheme.dividerColor),
                          _buildSettingItem(
                            icon: Icons.info_outline,
                            title: AppLang.t('app_version'),
                            trailing: Text(
                              'v1.0.0',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.pinkAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.glassBorder, width: 1.0),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(icon, color: AppTheme.textSecondary, size: 24),
      title: Text(
        title,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
      ),
      trailing:
          trailing ??
          Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSettingSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(icon, color: AppTheme.textSecondary, size: 24),
      title: Text(
        title,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.teal,
        activeTrackColor: Colors.teal.withValues(alpha: 0.3),
        inactiveThumbColor: AppTheme.textMuted,
        inactiveTrackColor: AppTheme.dividerColor,
      ),
    );
  }
}

// 10.(Personal Info Screen)
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _fullNameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _bloodTypeCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchPatientData();
  }

  // FUNCTION 1: FETCH DATA FROM SUPABASE
  Future<void> _fetchPatientData() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('patients')
          .select()
          .eq('id', QueueData.currentUserId) // Filter by the current user's ID
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _fullNameCtrl.text = response['full_name'] ?? '';
          _icCtrl.text = response['ic_number'] ?? '';
          _phoneCtrl.text = response['phone'] ?? '';
          _emailCtrl.text = response['email'] ?? '';
          _dobCtrl.text = response['dob'] ?? '';
          _bloodTypeCtrl.text =
              response['blood_type'] ??
              "Unverified"; // Set default value if blood type is null
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // FUNCTION 2: SAVE DATA TO SUPABASE
  Future<void> _saveProfileData() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('patients')
          .update({
            'full_name': _fullNameCtrl.text,
            'ic_number': _icCtrl.text,
            'phone': _phoneCtrl.text,
            'email': _emailCtrl.text,
            'dob': _dobCtrl.text,
            'blood_type': _bloodTypeCtrl.text,
          })
          .eq('id', QueueData.currentUserId);

      // Update the current user's name in QueueData after saving
      QueueData.currentUserName = _fullNameCtrl.text;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile details saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // FUNCTION 3: SELECT DATE FROM CALENDAR
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.pinkAccent,
              onPrimary: Colors.white,
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppTheme.isDark.value
                  ? Colors.grey[900]
                  : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      const List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      String day = picked.day.toString().padLeft(2, '0');
      String month = months[picked.month - 1];
      String year = picked.year.toString();

      setState(() {
        _dobCtrl.text = "$day $month $year";
      });
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _icCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _bloodTypeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Personal Info',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  GestureDetector(
                    onTap: _isSaving || _isLoading ? null : _saveProfileData,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.pinkAccent,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.pinkAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pinkAccent,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4DB6AC),
                                      Color(0xFF00838F),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.glassBorder,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.pinkAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 35),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.all(25),
                                decoration: BoxDecoration(
                                  color: AppTheme.glassBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.glassBorder,
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoField(
                                      label: 'Full Name',
                                      controller: _fullNameCtrl,
                                      icon: Icons.person_outline,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInfoField(
                                      label: 'IC Number / Passport',
                                      controller: _icCtrl,
                                      icon: Icons.badge_outlined,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInfoField(
                                      label: 'Phone Number',
                                      controller: _phoneCtrl,
                                      icon: Icons.phone_outlined,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInfoField(
                                      label: 'Email Address',
                                      controller: _emailCtrl,
                                      icon: Icons.email_outlined,
                                    ),
                                    const SizedBox(height: 20),

                                    _buildDobField(),
                                    const SizedBox(height: 20),

                                    _buildBloodTypeDropdown(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET TO FILL PERSONAL INFO FIELDS (FULL NAME, IC, PHONE, EMAIL)
  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _buildCustomTextField(
          icon: icon,
          hintText: '',
          obscureText: false,
          controller: controller,
        ),
      ],
    );
  }

  // WIDGET TO FILL DOB FIELD WITH CALENDAR PICKER
  Widget _buildDobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: AppTheme.glassBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    _dobCtrl.text.isEmpty
                        ? 'Select your date of birth'
                        : _dobCtrl.text,
                    style: TextStyle(
                      color: _dobCtrl.text.isEmpty
                          ? AppTheme.textMuted
                          : AppTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // WIDGET DROPDOWN FOR BLOOD TYPE SELECTION
  Widget _buildBloodTypeDropdown() {
    final List<String> bloodTypes = [
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
      'O+',
      'O-',
      "Unverified",
    ];

    if (!bloodTypes.contains(_bloodTypeCtrl.text) ||
        _bloodTypeCtrl.text.isEmpty) {
      _bloodTypeCtrl.text = "Unverified";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Blood Type',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: AppTheme.isDark.value
                  ? Colors.grey[900]
                  : Colors.white,
              value: _bloodTypeCtrl.text,
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              items: bloodTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  // BLOOD ICON
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _bloodTypeCtrl.text = newValue!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

class MedicalHistoryScreen extends StatelessWidget {
  const MedicalHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Medical History',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Medical history updated!'),
                        ),
                      );
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.pinkAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: AppTheme.glassBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.glassBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMedicalField(
                            label: 'Chronic Illnesses',
                            value: 'None',
                            icon: Icons.healing_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildMedicalField(
                            label: 'Allergies',
                            value: 'Penicillin, Peanuts',
                            icon: Icons.warning_amber_rounded,
                            isAlert: true,
                          ),
                          const SizedBox(height: 20),
                          _buildMedicalField(
                            label: 'Current Medications',
                            value: 'Loratadine (As needed)',
                            icon: Icons.medication_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildMedicalField(
                            label: 'Past Surgeries',
                            value: 'Appendectomy (2018)',
                            icon: Icons.content_cut_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildMedicalField(
                            label: 'Family Medical History',
                            value: 'Diabetes (Mother)\nHypertension (Father)',
                            icon: Icons.family_restroom_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalField({
    required String label,
    required String value,
    required IconData icon,
    bool isAlert = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAlert
                  ? Colors.orangeAccent.withValues(alpha: 0.5)
                  : AppTheme.glassBorder,
            ),
          ),
          child: TextField(
            controller: TextEditingController(text: value),
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            maxLines: null,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: isAlert
                    ? Colors.orangeAccent
                    : Colors.teal.withValues(alpha: 0.8),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 15,
                horizontal: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  int _selectedTab = 0; // 0: All, 1: Unread, 2: Read

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      bottomNavBar: _buildGlassBottomNavBar(context, currentIndex: 3),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // FILTER TAB (All / Unread / Read)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      child: _buildTabItem('All', isActive: _selectedTab == 0),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      child: _buildTabItem(
                        'Unread',
                        isActive: _selectedTab == 1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedTab = 2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      child: _buildTabItem('Read', isActive: _selectedTab == 2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // NOTIFICATION LIST
            Expanded(
              child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: QueueData.myNotifications,
                builder: (context, notifs, child) {
                  // FILTER NOTIFICATIONS BASED ON SELECTED TAB
                  List<Map<String, dynamic>> filteredList = [];
                  if (_selectedTab == 0) {
                    filteredList = notifs; // All
                  } else if (_selectedTab == 1) {
                    filteredList = notifs
                        .where((n) => n['isRead'] == false)
                        .toList(); // Unread
                  } else if (_selectedTab == 2) {
                    filteredList = notifs
                        .where((n) => n['isRead'] == true)
                        .toList(); // Read
                  }

                  if (filteredList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            color: AppTheme.textMuted.withValues(alpha: 0.5),
                            size: 60,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "No notifications yet.",
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final notif = filteredList[index];

                      // LOGIC BUTTON AND STATUS "I'M HERE"
                      Widget? extraContent;
                      if (notif['requiresAction'] == true &&
                          notif['isActioned'] == false) {
                        extraContent = Row(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pinkAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 5,
                                shadowColor: Colors.pinkAccent.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  QueueData.confirmPresence();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Presence Confirmed!"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: Text(
                                  "I'm Here",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else if (notif['requiresAction'] == true &&
                          notif['isActioned'] == true) {
                        extraContent = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.greenAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Presence Confirmed",
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // Mark notification as read when tapped, if it doesn't require action
                          if (!notif['requiresAction']) {
                            QueueData.markAsRead(notif['id']);
                          }
                        },
                        child: _buildNotificationCard(
                          title: notif['title'] ?? '',
                          message: notif['message'] ?? '',
                          time: notif['time'] ?? '',
                          isRead: notif['isRead'] ?? false,
                          extraContent: extraContent,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, {bool isActive = false}) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.pinkAccent : AppTheme.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        if (isActive)
          Container(
            width: 30,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.pinkAccent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.pinkAccent.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 3),
      ],
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String message,
    required String time,
    required bool isRead,
    Widget? extraContent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20), // Rounded corners for the card
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8,
            sigmaY: 8,
          ), // Glassmorphism effect
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isRead
                  ? AppTheme.glassBg
                  : Colors.pinkAccent.withValues(
                      alpha: 0.05,
                    ), // Slightly different background for unread notifications
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRead
                    ? AppTheme.glassBorder
                    : Colors.pinkAccent.withValues(
                        alpha: 0.5,
                      ), // Border color for unread notifications
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.pinkAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isRead
                          ? Colors.transparent
                          : Colors.pinkAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: isRead ? Colors.white54 : Colors.pinkAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: isRead
                              ? AppTheme.textMuted
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      if (extraContent != null) ...[
                        const SizedBox(height: 15),
                        extraContent,
                      ],
                      const SizedBox(height: 12),
                      Text(
                        time,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withValues(alpha: 0.5),
                          blurRadius: 5,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isChatInitialized = false;
List<Map<String, dynamic>> _globalMessages = [];
ChatSession? _globalChatSession;

// CHATBOT AI SCREEN WITH INDOOR NAVIGATION MAPPING (GEMINI PRO FLOW)
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _chatController = TextEditingController();
  bool _isLoading = false;

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "You are Q-Health AI, a smart indoor navigation and service assistant for the Q-Health hospital app. "
        "Your goal is to help patients find shops, cafes, and amenities inside the hospital while they wait for their queue turn.\n\n"
        "Here is the official hospital layout map:\n"
        "- GROUND FLOOR: Main Lobby, Hospital Pharmacy, Cooperative Convenience Store, ZUS Coffee.\n"
        "- LEVEL 1: Screening Room, Bakery & Snack Kiosk, Fruit Shop.\n"
        "- LEVEL 2: Consultation Room (Doctor's Room), Main Cafeteria (Food Court).\n\n"
        "STRICT INTERACTION RULES:\n"
        "1. When a user asks to find a shop, cafe, food, or location, DO NOT give the directions immediately. You MUST first politely ask for their current location (e.g., 'May I know where you are right now so I can help guide you?').\n"
        "2. Once they tell you their current location, provide clear, step-by-step indoor walking directions to their destination, detailing the floors to navigate and specific hospital landmarks to pass by.\n"
        "3. Always maintain a professional, helpful, and welcoming tone. You MUST reply in the same language used by the patient (Malay or English).",
      ),
    );

    if (!_isChatInitialized) {
      _globalChatSession = _model.startChat();

      _globalMessages.add({
        'text':
            "Hello! I am your Q-Health AI Assistant. While waiting for your turn, feel free to ask me if you want to find a cafe, convenience store, or any nearby shops!",
        'isAI': true,
      });

      _isChatInitialized = true;
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _globalChatSession == null) return;

    setState(() {
      _globalMessages.add({'text': text, 'isAI': false});
      _isLoading = true;
    });
    _chatController.clear();

    try {
      final response = await _globalChatSession!.sendMessage(
        Content.text(text),
      );
      final aiText = response.text;

      if (aiText != null) {
        setState(() {
          _globalMessages.add({'text': aiText, 'isAI': true});
        });
      }
    } catch (e) {
      debugPrint("====================================");
      debugPrint("ERROR : $e");
      debugPrint("====================================");

      setState(() {
        _globalMessages.add({
          'text':
              'The system is experiencing a technical issue. Please check your internet connection or API Key settings.',
          'isAI': true,
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      bottomNavBar: _buildGlassBottomNavBar(context, currentIndex: 4),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // TOP BAR SECTION (Kekal original)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.avatarBg,
                          border: Border.all(
                            color: Colors.pinkAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.pinkAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Assistant',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Online',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // MAIN MESSAGE LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    // LIST MESSAGE REFERRENCING GLOBAL VARIABLE
                    itemCount: _globalMessages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _globalMessages.length && _isLoading) {
                        return _buildLoadingBubble();
                      }
                      final msg = _globalMessages[index];
                      return _buildChatBubble(
                        text: msg['text'],
                        isAI: msg['isAI'],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 140),
              ],
            ),
          ),

          // PATIENT TEXT INPUT BOX
          Positioned(bottom: 90, left: 20, right: 20, child: _buildChatInput()),
        ],
      ),
    );
  }

  Widget _buildChatBubble({required String text, required bool isAI}) {
    return Align(
      alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAI
              ? AppTheme.glassBg
              : Colors.pinkAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAI ? 0 : 20),
            bottomRight: Radius.circular(isAI ? 20 : 0),
          ),
          border: Border.all(
            color: isAI
                ? AppTheme.glassBorder
                : Colors.pinkAccent.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.glassBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: AppTheme.glassBorder, width: 1),
        ),
        child: const SizedBox(
          width: 30,
          height: 15,
          child: CircularProgressIndicator(
            color: Colors.pinkAccent,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: "Ask AI anything...",
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.pinkAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

  // TIME CONTROLLER FUNCTION
  Future<int> _checkOperationStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://timeapi.io/api/Time/current/zone?timeZone=Asia/Kuala_Lumpur',
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        int currentHour = data['hour'];
        int currentMinute = data['minute'];

        int totalCurrentMinutes = (currentHour * 60) + currentMinute;
        int startOperationMinutes = 8 * 60; // 8:00 AM
        int endOperationMinutes = (16 * 60) + 30; // 4:30 PM

        if (totalCurrentMinutes >= startOperationMinutes &&
            totalCurrentMinutes <= endOperationMinutes) {
          return 1; // WITHIN OPERATION HOURS
        } else {
          return 0; // OUTSIDE OPERATION HOURS
        }
      } else {
        return 2; // 2 ERROR INTERNET / TIMEOUT
      }
    } catch (e) {
      debugPrint("Time Check Error: $e");
      return 2; // ERROR INTERNET / TIMEOUT
    }
  }

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
      final String aiServerUrl =
          'https://qhealth-ai-server.onrender.com/predict_ewt';
      int baseWaitTime = 25;

      // ONLY CALL AI SERVER IF THERE ARE PATIENTS AHEAD
      if (patientsAheadCount > 0) {
        try {
          DateTime now = DateTime.now();
          double exactHour = now.hour + (now.minute / 100.0);

          final aiResponse = await http
              .post(
                Uri.parse(aiServerUrl),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "Entry_Hour": exactHour,
                  "Entry_Day": now.weekday % 7,
                  "Patient Type": 1,
                  "Financial Class": 0,
                }),
              )
              .timeout(const Duration(seconds: 60));

          if (aiResponse.statusCode == 200) {
            final responseData = jsonDecode(aiResponse.body);
            if (responseData['success'] == true) {
              baseWaitTime = responseData['estimated_time_mins'];
            }
          }
        } catch (aiError) {
          debugPrint("AI Server cannot be connected : $aiError");
        }
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

      int calculatedWaitTime;
      if (patientsAheadCount == 0) {
        // If no patients are ahead, use a default wait time of 5 minutes
        calculatedWaitTime = 5;
      } else {
        calculatedWaitTime = maxExistingEwt + 5;
        if (calculatedWaitTime < baseWaitTime) {
          calculatedWaitTime = baseWaitTime;
        }
      }

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
        int delayInSeconds =
            (_estimatedWaitTime * 60) - 180; // Trigger 3 mins before
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
      bottomNavBar: _buildGlassBottomNavBar(context, currentIndex: 2),
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
                              final currentTimeInMins =
                                  (now.hour * 60) + now.minute;
                              final startMins = 8 * 60;
                              final endMins = (16 * 60) + 30;
                              bool isWithinHoursLocal =
                                  currentTimeInMins >= startMins &&
                                  currentTimeInMins <= endMins;
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
                                        int status =
                                            await _checkOperationStatus();

                                        if (mounted) {
                                          setState(
                                            () => _isCheckingTime = false,
                                          );
                                        }

                                        if (status == 1) {
                                          // STATUS 1: SYSTEM OPEN!
                                          _generateQueue();
                                        } else if (status == 0) {
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

// 12. STAFF LOGIN SCREEN
class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});
  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  bool _isLoading = false;
  bool _obscurePassword = true;

  // TextEditingController for Staff ID and Password
  final _staffIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _staffIdCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // FUNGSI BARU: Log masuk sebenar guna Supabase
  Future<void> _performLogin() async {
    if (_staffIdCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Staff ID and Password!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. CHECK IF STAFF ID EXISTS IN DATABASE
      final user = await supabase
          .from('staff')
          .select()
          .eq('staff_id', _staffIdCtrl.text)
          .maybeSingle();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff ID not found.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (user['password'] != _passwordCtrl.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect password!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // STAFF LOGIN SUCCESSFUL: STORE STAFF INFO IN QUEUE DATA
        QueueData.currentStaffTableId = user['id'].toString();
        QueueData.currentStaffName = user['full_name'] ?? 'Staff';
        QueueData.currentStaffRole = user['role'] ?? 'Healthcare Worker';
        QueueData.currentStaffDisplayId = user['staff_id'] ?? '-';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff Login Successful!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const StaffHomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 350,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 40,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.tealAccent.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.tealAccent.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                            image: const DecorationImage(
                              image: AssetImage('assets/staff_logo.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Staff Portal',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Authorized Personnel Only',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // STAFF ID INPUT FIELD
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _staffIdCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Staff ID',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        //BOX FOR PASSWORD
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 15,
                              ),
                              suffixIcon: GestureDetector(
                                onTap: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 35),
                        GestureDetector(
                          onTap: _isLoading ? null : _performLogin,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.teal,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 20),

                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Return to Patient Portal",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        int baseConsultWaitTime = 20; // Default fallback if AI fails
        final String aiConsultUrl = dotenv.env['AI_SERVER_URL'] ?? '';
        try {
          DateTime now = DateTime.now();
          double exactHour = now.hour + (now.minute / 100.0);

          final aiResponse = await http
              .post(
                Uri.parse(aiConsultUrl),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "Entry_Hour": exactHour,
                  "Queue_Length":
                      patientsWaitingForDoc, // Send queue length to AI
                  "Department": "General",
                }),
              )
              .timeout(const Duration(seconds: 5));

          if (aiResponse.statusCode == 200) {
            final responseData = jsonDecode(aiResponse.body);
            if (responseData['success'] == true) {
              baseConsultWaitTime = responseData['estimated_time_mins'];
            }
          }
        } catch (aiError) {
          debugPrint("AI Consult Server error: $aiError");
        }

        // 3. CALCULATE NEW DOCTOR EWT BASED ON QUEUE LENGTH AND AI PREDICTION
        int newDoctorEwt;

        if (patientsWaitingForDoc == 0) {
          // IF NO ONE IS WAITING, SET EWT TO 5 MINUTES
          newDoctorEwt = 5;
        } else if (maxConsultEwt == 0) {
          // Fallback
          newDoctorEwt = baseConsultWaitTime;
        } else {
          // SECOND PATIENT ONWARDS: ADD 15 MINUTES TO THE MAXIMUM EWT
          // This ensures that the next patient has a reasonable buffer time to see the doctor
          newDoctorEwt = maxConsultEwt + 15;

          if (newDoctorEwt < baseConsultWaitTime) {
            newDoctorEwt = baseConsultWaitTime;
          }
        }
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
        int delayConsult = (newDoctorEwt * 60) - 180;
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
      bottomNavigationBar: _buildStaffBottomNavBar(
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

// 14. STAFF PROFILE SCREEN (DYNAMIC)
class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
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
      final supabase = Supabase.instance.client;

      // Set the start of the day
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      String startIso = startOfDay.toUtc().toIso8601String();

      // Fetch all patients for today only from the database
      final response = await supabase
          .from('hospital_queue')
          .select('screening_status, consult_status')
          .gte('created_at', startIso);

      int completed = 0;
      int pending = 0;

      for (var record in response) {
        String sStatus = record['screening_status'] ?? '';
        String cStatus = record['consult_status'] ?? '';

        // Calculate how many patients have completed their process
        if (sStatus == 'Completed' || cStatus == 'Completed') {
          completed++;
        }
        // Calculate how many patients are still waiting
        if (sStatus == 'Waiting' || cStatus == 'Waiting') {
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
      bottomNavigationBar: _buildStaffBottomNavBar(
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

// Function to send push notification to a specific patient
Future<void> sendPushNotification(
  String targetPatientId,
  String title,
  String message,
) async {
  String oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  String oneSignalRestApiKey = dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

  var url = Uri.parse('https://onesignal.com/api/v1/notifications');

  var requestBody = jsonEncode({
    "app_id": oneSignalAppId,
    "target_channel": "push",
    "include_aliases": {
      "external_id": [targetPatientId], // Target patient by their external ID
    },
    "headings": {"en": title},
    "contents": {"en": message},
  });

  try {
    var response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": "Basic $oneSignalRestApiKey",
        "accept": "application/json",
      },
      body: requestBody,
    );

    if (response.statusCode == 200) {
      debugPrint(
        "Successfully sent push notification to patient: $targetPatientId",
      );
    } else {
      debugPrint("Failed to send notification: ${response.body}");
    }
  } catch (e) {
    debugPrint("Notification system error: $e");
  }
}

// FUNCTION: SCHEDULE PUSH NOTIFICATION
Future<void> sendScheduledPushNotification(
  String targetPatientId,
  String title,
  String message,
  int delayInSeconds,
) async {
  String oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  String oneSignalRestApiKey = dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

  var url = Uri.parse('https://onesignal.com/api/v1/notifications');

  // Calculate exact time to trigger notification (Current Time + Wait Time)
  DateTime sendTime = DateTime.now().toUtc().add(
    Duration(seconds: delayInSeconds),
  );
  String y = sendTime.year.toString();
  String m = sendTime.month.toString().padLeft(2, '0');
  String d = sendTime.day.toString().padLeft(2, '0');
  String h = sendTime.hour.toString().padLeft(2, '0');
  String min = sendTime.minute.toString().padLeft(2, '0');
  String s = sendTime.second.toString().padLeft(2, '0');

  // Format: "YYYY-MM-DD HH:MM:SS GMT+0000"
  String formattedTime = "$y-$m-$d $h:$min:$s GMT+0000";

  var requestBody = jsonEncode({
    "app_id": oneSignalAppId,
    "target_channel": "push",
    "include_aliases": {
      "external_id": [targetPatientId],
    },
    "headings": {"en": title},
    "contents": {"en": message},
    "send_after": formattedTime, // This tells OneSignal exactly WHEN to send it
  });

  try {
    await http.post(
      url,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": "Basic $oneSignalRestApiKey",
      },
      body: requestBody,
    );
  } catch (e) {
    debugPrint("Scheduling error: $e");
  }
}

// STAFF BOTTOM NAVIGATION BAR WIDGET
Widget _buildStaffBottomNavBar(
  BuildContext context, {
  required int currentIndex,
}) {
  return ClipRRect(
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(25),
      topRight: Radius.circular(25),
    ),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStaffBottomNavItem(
              icon: Icons.health_and_safety_outlined,
              title: 'Screening',
              isSelected: currentIndex == 0,
              activeColor: Colors.tealAccent,
              onTap: () {
                if (currentIndex != 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const StaffHomeScreen(isConsultation: false),
                    ),
                  );
                }
              },
            ),
            _buildStaffBottomNavItem(
              icon: Icons.medical_services_outlined,
              title: 'Consult',
              isSelected: currentIndex == 1,
              activeColor: Colors.blueAccent,
              onTap: () {
                if (currentIndex != 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const StaffHomeScreen(isConsultation: true),
                    ),
                  );
                }
              },
            ),
            _buildStaffBottomNavItem(
              icon: Icons.person_outline,
              title: 'Profile',
              isSelected: currentIndex == 2,
              activeColor: Colors.pinkAccent,
              onTap: () {
                if (currentIndex != 2) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StaffProfileScreen(),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildStaffBottomNavItem({
  required IconData icon,
  required String title,
  required bool isSelected,
  required Color activeColor,
  required VoidCallback onTap,
}) {
  final color = isSelected ? activeColor : Colors.white.withValues(alpha: 0.4);
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}

// TERMS & CONDITIONS (Q-HEALTH APP)
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

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
                    'Terms & Conditions',
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: AppTheme.glassBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Q-Health App Terms of Use',
                            style: TextStyle(
                              color: Colors.pinkAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Welcome to the Q-Health App. By using this application to request a queue number and monitor your wait time, you agree to the following terms:\n',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),

                          _buildSection(
                            title: '1. AI-Powered Time Estimation',
                            content:
                                'The Estimated Wait Time is generated by our Artificial Intelligence model based on real-time hospital operations. This time is an approximation. Actual waiting times may fluctuate due to unexpected delays or priority medical cases.',
                          ),
                          _buildSection(
                            title: '2. The 3-Minute Rule & Check-In',
                            content:
                                'Q-Health is designed to minimize overcrowding. When your remaining wait time reaches 3 minutes, the system will send an alert. You must physically be at the waiting area and tap the "I\'m Here" button. Failure to do so will result in your queue number being automatically skipped.',
                          ),
                          _buildSection(
                            title: '3. Safe Waiting Protocol',
                            content:
                                'While waiting, you are encouraged to wait in a safe, uncrowded space as monitored by the app. Please proceed to the exact consultation zone only when prompted by the system to maintain a safe environment for all patients.',
                          ),
                          _buildSection(
                            title: '4. Non-Emergency Use Only',
                            content:
                                'This application is strictly for standard appointments and outpatient queues. If you or someone else is experiencing a severe or life-threatening medical emergency, do not use this app. Proceed immediately to the Red Zone or Emergency Department.',
                          ),
                          _buildSection(
                            title: '5. Automated Status Updates',
                            content:
                                'Your queue status is automatically synchronized with the hospital database. Any attempt to manipulate the digital queue or bypass the presence confirmation protocol may result in appointment cancellation.',
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// COMPLETE PROFILE SCREEN (GOOGLE SIGN-IN)
class CompleteProfileScreen extends StatefulWidget {
  final String email;
  final String fullName;

  const CompleteProfileScreen({
    super.key,
    required this.email,
    required this.fullName,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _icController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    if (_icController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all information!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Split full name into first and last names
      List<String> nameParts = widget.fullName.split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts.first : '';
      String lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      // Insert new patient record into the database
      final response = await supabase
          .from('patients')
          .insert({
            'username': _usernameController.text,
            'full_name': widget.fullName,
            'first_name': firstName,
            'last_name': lastName,
            'email': widget.email,
            'ic_number': _icController.text,
            'phone': _phoneController.text,
            'password': 'oauth_google_account',
          })
          .select()
          .single();

      if (mounted) {
        // save data into global memory of the application
        QueueData.currentUserId = response['id'].toString();
        QueueData.currentUserName = response['full_name'] ?? 'Patient';

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile completed successfully! Welcome to Q-Health.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Back to main page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _icController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.glassBg,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Complete Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Account authenticated. Please choose a username and provide your details to activate your medical queue profile.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'Username',
                      obscureText: false,
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 15),
                    _buildCustomTextField(
                      icon: Icons.badge_outlined,
                      hintText: 'IC Number',
                      obscureText: false,
                      controller: _icController,
                    ),
                    const SizedBox(height: 15),
                    _buildCustomTextField(
                      icon: Icons.phone_outlined,
                      hintText: 'Phone Number',
                      obscureText: false,
                      controller: _phoneController,
                    ),
                    const SizedBox(height: 35),
                    GestureDetector(
                      onTap: _isLoading ? null : _saveProfile,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.glassBg,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppTheme.glassBorder,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.pinkAccent,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save & Continue',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

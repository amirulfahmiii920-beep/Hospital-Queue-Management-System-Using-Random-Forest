import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_lang.dart';
import '../../core/app_theme.dart';
import '../../core/queue_data.dart';
import '../../widgets/app_base_screen.dart';
import '../../widgets/patient_nav_bar.dart';
import 'get_queue_screen.dart';

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
      bottomNavBar: buildGlassBottomNavBar(context, currentIndex: 0),
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

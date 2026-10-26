import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../screens/patient/chatbot_screen.dart';
import '../screens/patient/get_queue_screen.dart';
import '../screens/patient/home_screen.dart';
import '../screens/patient/notification_screen.dart';
import '../screens/patient/profile_screen.dart';

Widget buildGlassBottomNavBar(
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
            buildBottomNavItem(
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
            buildBottomNavItem(
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
            buildBottomNavItem(
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
            buildBottomNavItem(
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
            buildBottomNavItem(
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

Widget buildBottomNavItem(
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

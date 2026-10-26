import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/queue_data.dart';
import '../../widgets/app_base_screen.dart';
import '../../widgets/patient_nav_bar.dart';
import 'home_screen.dart';

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
      bottomNavBar: buildGlassBottomNavBar(context, currentIndex: 3),
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

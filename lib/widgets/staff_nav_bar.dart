import 'dart:ui';

import 'package:flutter/material.dart';

import '../screens/staff/staff_home_screen.dart';
import '../screens/staff/staff_profile_screen.dart';

// STAFF BOTTOM NAVIGATION BAR WIDGET
Widget buildStaffBottomNavBar(
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
            buildStaffBottomNavItem(
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
            buildStaffBottomNavItem(
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
            buildStaffBottomNavItem(
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

Widget buildStaffBottomNavItem({
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

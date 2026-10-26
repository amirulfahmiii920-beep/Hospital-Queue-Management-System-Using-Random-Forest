import 'package:flutter/material.dart';

import '../core/app_theme.dart';

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

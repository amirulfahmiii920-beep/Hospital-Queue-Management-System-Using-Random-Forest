import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_lang.dart';
import '../../core/app_theme.dart';
import '../../core/queue_data.dart';
import '../../widgets/app_base_screen.dart';
import '../../widgets/patient_nav_bar.dart';
import '../auth/login_screen.dart';
import 'appointment_records_screen.dart';
import 'home_screen.dart';
import 'medical_history_screen.dart';
import 'personal_info_screen.dart';
import 'settings_screen.dart';

// 8. PROFILE SCREEN
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      bottomNavBar: buildGlassBottomNavBar(context, currentIndex: 1),
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

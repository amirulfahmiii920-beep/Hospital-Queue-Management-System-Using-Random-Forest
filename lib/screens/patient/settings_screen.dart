import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_lang.dart';
import '../../core/app_theme.dart';
import '../../widgets/app_base_screen.dart';
import '../auth/terms_and_conditions_screen.dart';

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

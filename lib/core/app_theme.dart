import 'package:flutter/material.dart';

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

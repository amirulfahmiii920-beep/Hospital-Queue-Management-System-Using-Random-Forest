import 'package:flutter/material.dart';

import '../core/app_theme.dart';

Widget buildCustomTextField({
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

Widget buildOrDivider() {
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

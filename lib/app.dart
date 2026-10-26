import 'package:flutter/material.dart';

import 'core/app_lang.dart';
import 'core/app_theme.dart';
import 'screens/auth/login_screen.dart';

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

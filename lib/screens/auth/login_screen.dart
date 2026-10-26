import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../core/queue_data.dart';
import '../../data/auth_repository.dart';
import '../../data/patient_repository.dart';
import '../../widgets/app_base_screen.dart';
import '../../widgets/form_widgets.dart';
import '../patient/home_screen.dart';
import '../staff/staff_login_screen.dart';
import 'complete_profile_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

// =========================================================================
// 5. LOGIN SCREEN FOR PATIENT
// =========================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PatientRepository _patients = const PatientRepository();
  final AuthRepository _auth = const AuthRepository();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true; // EYE ICON FOR PASSWORD FIELD

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Load saved credentials on init

    _auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        final user = session.user;

        final patientRecord = await _patients.findByEmail(user.email ?? '');

        if (patientRecord == null) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CompleteProfileScreen(
                  email: user.email ?? '',
                  fullName: user.userMetadata?['full_name'] ?? 'New Patient',
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            QueueData.currentUserId = patientRecord['id'].toString();
            QueueData.currentUserName = patientRecord['full_name'] ?? 'Patient';

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login Successful via Google!'),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      }
    });
  }

  // ==========================================
  // LATEST CODE: READ SAVED CREDENTIALS
  // ==========================================
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('remember_username');
    final savedPassword = prefs.getString('remember_password');
    final isRemembered = prefs.getBool('remember_me') ?? false;

    if (isRemembered && savedUsername != null && savedPassword != null) {
      setState(() {
        _usernameController.text = savedUsername;
        _passwordController.text = savedPassword;
        _rememberMe = isRemembered;
      });
    }
  }

  Future<void> _loginUser() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Username and Password!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _patients.findByUsername(_usernameController.text);

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Username does not exist. Please register an account.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (user['password'] != _passwordController.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect password! Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setString(
              'remember_username',
              _usernameController.text,
            );
            await prefs.setString(
              'remember_password',
              _passwordController.text,
            );
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('remember_username');
            await prefs.remove('remember_password');
            await prefs.setBool('remember_me', false);
          }

          QueueData.currentUserId = user['id'].toString();
          String firstName = user['first_name'] ?? '';
          String lastName = user['last_name'] ?? '';
          String displayName = (firstName.isNotEmpty || lastName.isNotEmpty)
              ? '$firstName $lastName'.trim()
              : (user['full_name'] ?? 'Patient');
          QueueData.currentUserName = displayName;

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login Successful!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 350,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.glassBg,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'Username',
                      obscureText: false,
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 20),

                    // LATEST CODE: PASSWORD FIELD WITH EYE ICON
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.glassBg,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 20,
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ==========================================
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (bool? newValue) {
                              setState(() {
                                _rememberMe = newValue!;
                              });
                            },
                            activeColor: Colors.pinkAccent,
                            checkColor: Colors.white,
                            side: BorderSide(color: AppTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember Me',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 35),
                    GestureDetector(
                      onTap: _isLoading ? null : _loginUser,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.glassBg,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppTheme.glassBorder,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.pinkAccent,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Sign In',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    buildOrDivider(),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await _auth.signInWithGoogle();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Google Sign-In Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: AppTheme.glassBg,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppTheme.glassBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 15),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Register",
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'forgot password?',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(height: 1, color: AppTheme.dividerColor),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StaffLoginScreen(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.health_and_safety,
                            color: Colors.teal,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Healthcare Provider? ",
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            "Staff Portal",
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

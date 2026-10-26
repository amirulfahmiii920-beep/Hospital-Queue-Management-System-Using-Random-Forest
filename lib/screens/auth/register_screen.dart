import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../widgets/app_base_screen.dart';
import '../../widgets/form_widgets.dart';

// 6. REGISTER SCREEN FOR NEW PATIENT & FORGET PASSWORD
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _icController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _registerUser() async {
    if (_usernameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _fullNameController.text.isEmpty ||
        _icController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all important information!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('patients').insert({
        'username': _usernameController.text,
        'password': _passwordController.text,
        'full_name': _fullNameController.text,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'ic_number': _icController.text,
        'phone': _phoneController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration Successful! Please Login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration Error: $e'),
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
    _fullNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _icController.dispose();
    _phoneController.dispose();
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
                        'Register',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    buildCustomTextField(
                      icon: Icons.alternate_email,
                      hintText: 'Username',
                      obscureText: false,
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 15),
                    buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'Full Name(as per IC)',
                      obscureText: false,
                      controller: _fullNameController,
                    ),
                    const SizedBox(
                      height: 15,
                    ), // DISTANCE BETWEEN FULL NAME AND FIRST NAME
                    buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'First Name',
                      obscureText: false,
                      controller: _firstNameController,
                    ),
                    const SizedBox(
                      height: 15,
                    ), // DISTANCE BETWEEN FIRST NAME AND LAST NAME
                    buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'Last Name',
                      obscureText: false,
                      controller: _lastNameController,
                    ),
                    const SizedBox(height: 15),
                    buildCustomTextField(
                      icon: Icons.mail_outline,
                      hintText: 'Email Address',
                      obscureText: false,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 15),
                    buildCustomTextField(
                      icon: Icons.badge_outlined,
                      hintText: 'IC Number',
                      obscureText: false,
                      controller: _icController,
                    ),
                    const SizedBox(height: 15),
                    buildCustomTextField(
                      icon: Icons.phone_outlined,
                      hintText: 'Phone Number',
                      obscureText: false,
                      controller: _phoneController,
                    ),
                    const SizedBox(height: 15),
                    buildCustomTextField(
                      icon: Icons.lock_outline,
                      hintText: 'Password',
                      obscureText: true,
                      controller: _passwordController,
                    ),
                    const SizedBox(height: 35),

                    GestureDetector(
                      onTap: _isLoading ? null : _registerUser,
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
                                'Create Account',
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
                      onTap: () {},
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
                          "Already have an account? ",
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Login",
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

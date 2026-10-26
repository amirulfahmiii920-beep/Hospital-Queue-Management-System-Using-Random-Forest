import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/queue_data.dart';
import '../../data/patient_repository.dart';
import '../../widgets/app_base_screen.dart';
import '../../widgets/form_widgets.dart';
import '../patient/home_screen.dart';

// COMPLETE PROFILE SCREEN (GOOGLE SIGN-IN)
class CompleteProfileScreen extends StatefulWidget {
  final String email;
  final String fullName;

  const CompleteProfileScreen({
    super.key,
    required this.email,
    required this.fullName,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final PatientRepository _patients = const PatientRepository();

  final _icController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    if (_icController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all information!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Split full name into first and last names
      List<String> nameParts = widget.fullName.split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts.first : '';
      String lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      // Insert new patient record into the database
      final response = await _patients.createAndReturn({
        'username': _usernameController.text,
        'full_name': widget.fullName,
        'first_name': firstName,
        'last_name': lastName,
        'email': widget.email,
        'ic_number': _icController.text,
        'phone': _phoneController.text,
        'password': 'oauth_google_account',
      });

      if (mounted) {
        // save data into global memory of the application
        QueueData.currentUserId = response['id'].toString();
        QueueData.currentUserName = response['full_name'] ?? 'Patient';

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile completed successfully! Welcome to Q-Health.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Back to main page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
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
    _icController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
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
                        'Complete Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Account authenticated. Please choose a username and provide your details to activate your medical queue profile.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 30),
                    buildCustomTextField(
                      icon: Icons.person_outline,
                      hintText: 'Username',
                      obscureText: false,
                      controller: _usernameController,
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
                    const SizedBox(height: 35),
                    GestureDetector(
                      onTap: _isLoading ? null : _saveProfile,
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
                                'Save & Continue',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

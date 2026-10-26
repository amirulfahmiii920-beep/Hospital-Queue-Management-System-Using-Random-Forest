import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/queue_data.dart';
import '../../data/patient_repository.dart';
import '../../widgets/app_base_screen.dart';
import '../../widgets/form_widgets.dart';

// 10.(Personal Info Screen)
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final PatientRepository _patients = const PatientRepository();

  final _fullNameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _bloodTypeCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchPatientData();
  }

  // FUNCTION 1: FETCH DATA FROM SUPABASE
  Future<void> _fetchPatientData() async {
    try {
      final response = await _patients.findById(QueueData.currentUserId);

      if (response != null && mounted) {
        setState(() {
          _fullNameCtrl.text = response['full_name'] ?? '';
          _icCtrl.text = response['ic_number'] ?? '';
          _phoneCtrl.text = response['phone'] ?? '';
          _emailCtrl.text = response['email'] ?? '';
          _dobCtrl.text = response['dob'] ?? '';
          _bloodTypeCtrl.text =
              response['blood_type'] ??
              "Unverified"; // Set default value if blood type is null
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // FUNCTION 2: SAVE DATA TO SUPABASE
  Future<void> _saveProfileData() async {
    setState(() => _isSaving = true);
    try {
      await _patients.update(QueueData.currentUserId, {
        'full_name': _fullNameCtrl.text,
        'ic_number': _icCtrl.text,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'dob': _dobCtrl.text,
        'blood_type': _bloodTypeCtrl.text,
      });

      // Update the current user's name in QueueData after saving
      QueueData.currentUserName = _fullNameCtrl.text;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile details saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // FUNCTION 3: SELECT DATE FROM CALENDAR
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.pinkAccent,
              onPrimary: Colors.white,
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppTheme.isDark.value
                  ? Colors.grey[900]
                  : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      const List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      String day = picked.day.toString().padLeft(2, '0');
      String month = months[picked.month - 1];
      String year = picked.year.toString();

      setState(() {
        _dobCtrl.text = "$day $month $year";
      });
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _icCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _bloodTypeCtrl.dispose();
    super.dispose();
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Personal Info',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  GestureDetector(
                    onTap: _isSaving || _isLoading ? null : _saveProfileData,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.pinkAccent,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.pinkAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pinkAccent,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4DB6AC),
                                      Color(0xFF00838F),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.glassBorder,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.pinkAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 35),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.all(25),
                                decoration: BoxDecoration(
                                  color: AppTheme.glassBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.glassBorder,
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoField(
                                      label: 'Full Name',
                                      controller: _fullNameCtrl,
                                      icon: Icons.person_outline,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInfoField(
                                      label: 'IC Number / Passport',
                                      controller: _icCtrl,
                                      icon: Icons.badge_outlined,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInfoField(
                                      label: 'Phone Number',
                                      controller: _phoneCtrl,
                                      icon: Icons.phone_outlined,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInfoField(
                                      label: 'Email Address',
                                      controller: _emailCtrl,
                                      icon: Icons.email_outlined,
                                    ),
                                    const SizedBox(height: 20),

                                    _buildDobField(),
                                    const SizedBox(height: 20),

                                    _buildBloodTypeDropdown(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET TO FILL PERSONAL INFO FIELDS (FULL NAME, IC, PHONE, EMAIL)
  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        buildCustomTextField(
          icon: icon,
          hintText: '',
          obscureText: false,
          controller: controller,
        ),
      ],
    );
  }

  // WIDGET TO FILL DOB FIELD WITH CALENDAR PICKER
  Widget _buildDobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: AppTheme.glassBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    _dobCtrl.text.isEmpty
                        ? 'Select your date of birth'
                        : _dobCtrl.text,
                    style: TextStyle(
                      color: _dobCtrl.text.isEmpty
                          ? AppTheme.textMuted
                          : AppTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // WIDGET DROPDOWN FOR BLOOD TYPE SELECTION
  Widget _buildBloodTypeDropdown() {
    final List<String> bloodTypes = [
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
      'O+',
      'O-',
      "Unverified",
    ];

    if (!bloodTypes.contains(_bloodTypeCtrl.text) ||
        _bloodTypeCtrl.text.isEmpty) {
      _bloodTypeCtrl.text = "Unverified";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Blood Type',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: AppTheme.isDark.value
                  ? Colors.grey[900]
                  : Colors.white,
              value: _bloodTypeCtrl.text,
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              items: bloodTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  // BLOOD ICON
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _bloodTypeCtrl.text = newValue!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/app_base_screen.dart';

class MedicalHistoryScreen extends StatelessWidget {
  const MedicalHistoryScreen({super.key});
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
                    'Medical History',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Medical history updated!'),
                        ),
                      );
                    },
                    child: const Text(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
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
                          _buildMedicalField(
                            label: 'Chronic Illnesses',
                            value: 'None',
                            icon: Icons.healing_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildMedicalField(
                            label: 'Allergies',
                            value: 'Penicillin, Peanuts',
                            icon: Icons.warning_amber_rounded,
                            isAlert: true,
                          ),
                          const SizedBox(height: 20),
                          _buildMedicalField(
                            label: 'Current Medications',
                            value: 'Loratadine (As needed)',
                            icon: Icons.medication_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildMedicalField(
                            label: 'Past Surgeries',
                            value: 'Appendectomy (2018)',
                            icon: Icons.content_cut_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildMedicalField(
                            label: 'Family Medical History',
                            value: 'Diabetes (Mother)\nHypertension (Father)',
                            icon: Icons.family_restroom_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalField({
    required String label,
    required String value,
    required IconData icon,
    bool isAlert = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAlert
                  ? Colors.orangeAccent.withValues(alpha: 0.5)
                  : AppTheme.glassBorder,
            ),
          ),
          child: TextField(
            controller: TextEditingController(text: value),
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            maxLines: null,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: isAlert
                    ? Colors.orangeAccent
                    : Colors.teal.withValues(alpha: 0.8),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 15,
                horizontal: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

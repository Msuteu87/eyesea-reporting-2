import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

/// A submit button for reports that shows EyeSea Credits earned and handles people detection blocking.
class ReportSubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final bool hasPeopleDetected;
  final int totalXP;
  final VoidCallback? onSubmit;

  const ReportSubmitButton({
    super.key,
    required this.isSubmitting,
    required this.hasPeopleDetected,
    required this.totalXP,
    required this.onSubmit,
  });

  bool get _isDisabled => isSubmitting || hasPeopleDetected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Column(
      children: [
        if (hasPeopleDetected) _buildPeopleDetectedWarning(),
        _buildButton(primaryColor),
      ],
    );
  }

  Widget _buildPeopleDetectedWarning() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.punchRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.punchRed),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.userX, color: AppColors.punchRed),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'For privacy reasons, you cannot submit reports containing people. Please retake the photo.',
                style: TextStyle(
                  color: AppColors.punchRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildButton(Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _isDisabled ? null : onSubmit,
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          disabledBackgroundColor: hasPeopleDetected
              ? Colors.grey[400]
              : primaryColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isSubmitting ? _buildLoadingIndicator() : _buildButtonContent(),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Colors.white,
      ),
    );
  }

  Widget _buildButtonContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(LucideIcons.send, size: 20),
        const SizedBox(width: 12),
        Text(
          hasPeopleDetected
              ? 'Cannot Submit (People Detected)'
              : 'Submit Report (+$totalXP Credits)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import 'legal_viewer_screen.dart';

/// Consolidated legal menu screen with all legal documents.
class LegalMenuScreen extends StatelessWidget {
  const LegalMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLegalItem(
            context,
            title: 'Terms of Service',
            subtitle: 'Terms and conditions for using the app',
            icon: LucideIcons.fileText,
            onTap: () => _openDocument(
              context,
              'Terms of Service',
              'assets/legal/terms_of_service.md',
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildLegalItem(
            context,
            title: 'Privacy Policy',
            subtitle: 'How we collect and handle your data',
            icon: LucideIcons.shield,
            onTap: () => _openDocument(
              context,
              'Privacy Policy',
              'assets/legal/privacy_policy.md',
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildLegalItem(
            context,
            title: 'End User License Agreement',
            subtitle: 'Software license terms',
            icon: LucideIcons.fileBadge,
            onTap: () => _openDocument(
              context,
              'EULA',
              'assets/legal/eula.md',
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildLegalItem(
            context,
            title: 'Open Source Licenses',
            subtitle: 'Third-party software acknowledgements',
            icon: LucideIcons.code2,
            onTap: () => _showOpenSourceLicenses(context),
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© 2025 Eyesea. All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.oceanBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.oceanBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDocument(BuildContext context, String title, String assetPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LegalViewerScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }

  void _showOpenSourceLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Eyesea Reporting',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 Eyesea. All rights reserved.',
    );
  }
}

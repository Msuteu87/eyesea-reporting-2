import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../legal/legal_viewer_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  // Theme
  ThemeMode _themeMode = ThemeMode.system;

  // Notifications
  bool _notificationsEnabled = false;
  bool _isCheckingNotifications = true;

  // Expert Mode (bounding boxes on camera)
  bool _expertModeEnabled = false;
  static const String _expertModeKey = 'expert_mode_enabled';

  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = context.read<NotificationService>();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load theme preference
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];

    // Load expert mode preference
    _expertModeEnabled = prefs.getBool(_expertModeKey) ?? false;

    // Check notification permission
    await _checkNotificationPermission();

    if (mounted) setState(() {});
  }

  Future<void> _checkNotificationPermission() async {
    if (!mounted) return;
    setState(() => _isCheckingNotifications = true);
    try {
      _notificationsEnabled = await _notificationService.checkPermission();
    } catch (_) {
      _notificationsEnabled = false;
    } finally {
      if (mounted) setState(() => _isCheckingNotifications = false);
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Theme will apply on next app restart'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (enabled) {
      final granted = await _notificationService.requestPermission();
      if (mounted) {
        setState(() => _notificationsEnabled = granted);

        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable notifications in system settings'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disable notifications in system settings'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _toggleExpertMode(bool enabled) async {
    setState(() => _expertModeEnabled = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expertModeKey, enabled);
  }

  Future<void> _handleChangePassword() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text(
          'We\'ll send a password reset link to your email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(user.email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Password reset email sent!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _openLegalDocument(BuildContext context, String title, String assetPath) {
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
      applicationLegalese: '© 2025 Marius Catalin Suteu / Eyesea. All rights reserved.',
    );
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action cannot be undone. All your data including reports will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion is not yet available. Please contact support.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        // Appearance Section
        _buildSectionHeader(context, 'Appearance', LucideIcons.palette),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          children: [
            _buildThemeSelector(context, theme),
          ],
        ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1),

        const SizedBox(height: 24),

        // Notifications Section
        _buildSectionHeader(context, 'Notifications', LucideIcons.bell),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          children: [
            _buildSwitchTile(
              context,
              title: 'Push Notifications',
              subtitle: 'Get notified about report updates',
              icon: LucideIcons.bellRing,
              value: _notificationsEnabled,
              isLoading: _isCheckingNotifications,
              onChanged: _toggleNotifications,
            ),
          ],
        ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.1),

        const SizedBox(height: 24),

        // Account Section
        _buildSectionHeader(context, 'Account', LucideIcons.user),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          children: [
            _buildActionTile(
              context,
              title: 'Change Password',
              subtitle: 'Send a password reset email',
              icon: LucideIcons.key,
              onTap: _handleChangePassword,
            ),
            const Divider(height: 1),
            _buildActionTile(
              context,
              title: 'Delete Account',
              subtitle: 'Permanently remove your account and data',
              icon: LucideIcons.trash2,
              isDestructive: true,
              onTap: _handleDeleteAccount,
            ),
          ],
        ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),

        const SizedBox(height: 24),

        // Legal Section
        _buildSectionHeader(context, 'Legal', LucideIcons.scale),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          children: [
            _buildActionTile(
              context,
              title: 'Terms of Service',
              subtitle: 'Read our terms and conditions',
              icon: LucideIcons.fileText,
              onTap: () => _openLegalDocument(
                context,
                'Terms of Service',
                'assets/legal/terms_of_service.md',
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              context,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              icon: LucideIcons.shield,
              onTap: () => _openLegalDocument(
                context,
                'Privacy Policy',
                'assets/legal/privacy_policy.md',
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              context,
              title: 'EULA',
              subtitle: 'End User License Agreement',
              icon: LucideIcons.fileBadge,
              onTap: () => _openLegalDocument(
                context,
                'EULA',
                'assets/legal/eula.md',
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              context,
              title: 'Open Source Licenses',
              subtitle: 'Third-party software licenses',
              icon: LucideIcons.code2,
              onTap: () => _showOpenSourceLicenses(context),
            ),
          ],
        ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.1),

        const SizedBox(height: 24),

        // Advanced Section (Expert Mode)
        _buildSectionHeader(context, 'Advanced', LucideIcons.settings2),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          children: [
            _buildSwitchTile(
              context,
              title: 'Expert Mode',
              subtitle: 'Show AI detection boxes on camera',
              icon: LucideIcons.scanLine,
              value: _expertModeEnabled,
              onChanged: _toggleExpertMode,
            ),
          ],
        ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),

        const SizedBox(height: 32),

        // Logout Button
        OutlinedButton.icon(
          onPressed: () => context.read<AuthProvider>().signOut(),
          icon: const Icon(LucideIcons.logOut, color: AppColors.error),
          label: const Text('Log Out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ).animate().fadeIn(delay: 250.ms),

        const SizedBox(height: 24),

        // Version info
        Center(
          child: Text(
            'Eyesea Reporting v1.0.0',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildThemeSelector(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sun, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Theme',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildThemeOption(context, 'System', ThemeMode.system),
              const SizedBox(width: 8),
              _buildThemeOption(context, 'Light', ThemeMode.light),
              const SizedBox(width: 8),
              _buildThemeOption(context, 'Dark', ThemeMode.dark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    ThemeMode mode,
  ) {
    final theme = Theme.of(context);
    final isSelected = _themeMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => _setThemeMode(mode),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? theme.colorScheme.primary : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
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
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final color = isDestructive ? AppColors.error : theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? AppColors.error : null,
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
    );
  }
}

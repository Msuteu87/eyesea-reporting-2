import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/logger.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_map_provider.dart';
import '../legal/legal_viewer_screen.dart';
import '../widgets/onboarding_animations.dart';
import 'registration_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final int initialPage;
  const OnboardingScreen({
    super.key,
    this.initialPage = 0,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  late int _currentPage;

  // Track retry attempts per permission
  final Map<Permission, int> _permissionAttempts = {};

  // Track granted permissions for success animation
  final Map<Permission, bool> _permissionGrantedStates = {};

  // Track which permission pages have been shown to the user at least once
  // This prevents auto-advancing on first visit due to false positive permission status
  final Set<int> _shownPermissionPages = {};

  // Prevent duplicate navigation calls (race condition lock)
  bool _isNavigating = false;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Welcome to Eyesea',
      description:
          'Let\'s get your profile set up so you can start making a difference.',
      imagePath: 'assets/images/onboarding_camera.png',
      permission: null,
      buttonText: 'Continue',
      isRegistrationPage: true,
    ),
    OnboardingPageData(
      title: 'Capture the Evidence',
      description:
          'Take photos of pollution to report it instantly. Your camera helps us see what you see.',
      imagePath: 'assets/images/onboarding_camera.png',
      permission: Permission.camera,
      buttonText: 'Enable Camera Access',
    ),
    OnboardingPageData(
      title: 'Pinpoint the Pollution',
      description:
          'We need your location to map the data accurately. Help us track where cleanup is needed most.',
      imagePath: 'assets/images/onboarding_location.png',
      permission: Permission.location,
      buttonText: 'Enable Location Access',
    ),
    OnboardingPageData(
      title: 'Upload from History',
      description:
          'Found an old photo of pollution? Access your gallery to report past sightings.',
      imagePath: 'assets/images/onboarding_gallery.png',
      permission: Permission.photos,
      buttonText: 'Enable Photo Access',
    ),
    OnboardingPageData(
      title: 'Stay in the Loop',
      description:
          'Get notified when your reports are verified or when pollution you reported gets cleaned up.',
      imagePath: 'assets/images/onboarding_notifications.png',
      permission: Permission.notification,
      buttonText: 'Enable Notifications',
      isNotificationPage: true,
    ),
    OnboardingPageData(
      title: 'Terms & Conditions',
      description:
          'By using Eyesea, you agree to our Terms of Service and Privacy Policy. Tap to read the full documents.',
      imagePath: 'assets/images/onboarding_gallery.png',
      permission: null,
      buttonText: 'I Agree & Get Started',
      isTermsPage: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppLogger.info('[Onboarding] App resumed. Checking permission...');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkCurrentPagePermissionOnResume();
        }
      });
    }
  }

  /// Called ONLY when returning from Settings (app resumed).
  /// This checks if the user granted permission while in Settings.
  Future<void> _checkCurrentPagePermissionOnResume() async {
    // Don't check if already navigating
    if (_isNavigating) {
      AppLogger.debug('[Onboarding] Skipping resume check - already navigating');
      return;
    }

    final pageIndexWhenCalled = _currentPage;
    final pageData = _pages[_currentPage];

    // Handle notification page specially
    if (pageData.isNotificationPage) {
      final hasBeenShown = _shownPermissionPages.contains(_currentPage);
      final notificationService = context.read<NotificationService>();
      final granted = await notificationService.checkPermission();
      AppLogger.debug('[Onboarding] Resume check: notification = $granted, hasBeenShown = $hasBeenShown');

      if (granted && _currentPage == pageIndexWhenCalled && !_isNavigating && hasBeenShown) {
        setState(() {
          _permissionGrantedStates[Permission.notification] = true;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        _goToNextPage();
      }
      return;
    }

    if (pageData.permission != null) {
      final status = await pageData.permission!.status;
      AppLogger.debug('[Onboarding] Resume check: ${pageData.permission} = $status');

      // ONLY auto-advance if:
      // 1. Permission is actually granted/limited
      // 2. User has already seen this page (returned from Settings)
      // This prevents false-positive auto-skipping on first visit
      final hasBeenShown = _shownPermissionPages.contains(_currentPage);

      if ((status.isGranted || status.isLimited) &&
          _currentPage == pageIndexWhenCalled &&
          !_isNavigating &&
          hasBeenShown) {
        AppLogger.info('[Onboarding] Permission granted on resume. Advancing from page $pageIndexWhenCalled.');
        // Mark as granted for animation
        setState(() {
          _permissionGrantedStates[pageData.permission!] = true;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        _goToNextPage();
      }
    }
  }

  /// Get list of missing permissions
  Future<List<Permission>> _getMissingPermissions() async {
    final missing = <Permission>[];

    final cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      missing.add(Permission.camera);
    }

    final locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      missing.add(Permission.location);
    }

    final photosStatus = await Permission.photos.status;
    if (!photosStatus.isGranted && !photosStatus.isLimited) {
      missing.add(Permission.photos);
    }

    return missing;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                physics: const NeverScrollableScrollPhysics(),
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  // NOTE: Don't check permissions here - it causes random skipping
                  // when permissions are already granted. Only check on resume from Settings.
                },
                itemBuilder: (context, index) {
                  final data = _pages[index];

                  if (data.isRegistrationPage) {
                    return RegistrationScreen(
                      onCompleted: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                    );
                  }

                  return Stack(
                    children: [
                      // Ocean wave background
                      if (data.permission != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: AnimatedOceanWave(
                            waveColor: theme.colorScheme.primary,
                            height: 120,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildPageContent(data, theme),
                            ),
                            const SizedBox(height: 32),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Text(
                                    data.title,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(delay: 400.ms)
                                      .slideY(begin: 0.2, end: 0),
                                  const SizedBox(height: 16),
                                  Text(
                                    data.description,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontFamily: 'Roboto',
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                      height: 1.5,
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(delay: 600.ms)
                                      .slideY(begin: 0.2, end: 0),
                                  if (data.isTermsPage) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextButton(
                                          onPressed: () => _openLegalDocument(
                                              'Terms of Service',
                                              'assets/legal/terms_of_service.md'),
                                          child: Text('Terms',
                                              style: TextStyle(
                                                  color: theme
                                                      .colorScheme.primary)),
                                        ),
                                        const Text(' • '),
                                        TextButton(
                                          onPressed: () => _openLegalDocument(
                                              'Privacy Policy',
                                              'assets/legal/privacy_policy.md'),
                                          child: Text('Privacy',
                                              style: TextStyle(
                                                  color: theme
                                                      .colorScheme.primary)),
                                        ),
                                        const Text(' • '),
                                        TextButton(
                                          onPressed: () => _openLegalDocument(
                                              'EULA', 'assets/legal/eula.md'),
                                          child: Text('EULA',
                                              style: TextStyle(
                                                  color: theme
                                                      .colorScheme.primary)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Controls (Hide for Registration Page)
            if (!_pages[_currentPage].isRegistrationPage)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.primary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () => _handlePermissionAndNext(),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1
                              ? 'Get Started'
                              : _pages[_currentPage].buttonText,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                        .animate(
                            target: _currentPage == _pages.length - 1 ? 1 : 0)
                        .shimmer(duration: 1200.ms, color: Colors.white54),
                    // SKIP BUTTON REMOVED - Permissions are required
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build the visual content (icon/image) for each onboarding page
  Widget _buildPageContent(OnboardingPageData data, ThemeData theme) {
    // Terms & Conditions page - animated gavel icon
    if (data.isTermsPage) {
      return Icon(
        Icons.gavel,
        size: 120,
        color: theme.colorScheme.primary,
      )
          .animate()
          .fade(duration: 600.ms)
          .scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack);
    }

    // Permission pages - use pulsing animated icons
    if (data.permission != null) {
      final isGranted = _permissionGrantedStates[data.permission] ?? false;
      IconData iconData;

      switch (data.permission!) {
        case Permission.camera:
          iconData = Icons.camera_alt_rounded;
        case Permission.location:
        case Permission.locationWhenInUse:
        case Permission.locationAlways:
          iconData = Icons.location_on_rounded;
        case Permission.photos:
        case Permission.storage:
        case Permission.mediaLibrary:
          iconData = Icons.photo_library_rounded;
        case Permission.notification:
          iconData = Icons.notifications_rounded;
        default:
          iconData = Icons.security_rounded;
      }

      // Permission pages - centered pulsing animated icons only
      return Center(
        child: PulsingPermissionIcon(
          icon: iconData,
          color: theme.colorScheme.primary,
          size: 120,
          isGranted: isGranted,
        ),
      );
    }

    // Fallback - use static image (registration page uses its own UI)
    return Image.asset(
      data.imagePath,
      fit: BoxFit.contain,
    )
        .animate()
        .fade(duration: 600.ms)
        .scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack);
  }

  Future<void> _handlePermissionAndNext() async {
    final pageData = _pages[_currentPage];

    // --- T&C Page: Verify all permissions before completing ---
    if (pageData.isTermsPage) {
      final missingPermissions = await _getMissingPermissions();
      if (missingPermissions.isNotEmpty) {
        if (mounted) {
          // Show dialog explaining which permissions are missing
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Permissions Required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Please enable the following permissions to continue:'),
                  const SizedBox(height: 12),
                  ...missingPermissions.map((p) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.close, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Text(_getPermissionName(p)),
                          ],
                        ),
                      )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await openAppSettings();
          }
        }
        return;
      }

      if (!mounted) return;
      await context.read<AuthProvider>().acceptTerms();
      if (!mounted) return;
      await context.read<AuthProvider>().setOnboardingComplete();

      if (mounted && context.read<AuthProvider>().isOnboardingComplete) {
        // Force refresh the map provider to ensure fresh state after permissions
        AppLogger.info('[Onboarding] Refreshing ReportsMapProvider before navigation...');
        context.read<ReportsMapProvider>().refresh();
        context.go('/');
      }
      return;
    }

    // --- Notification Page: Use NotificationService instead of permission_handler ---
    if (pageData.isNotificationPage && !kIsWeb) {
      // Mark page as shown so auto-advance works when returning from Settings
      _shownPermissionPages.add(_currentPage);

      final notificationService = context.read<NotificationService>();
      final granted = await notificationService.requestPermission();

      AppLogger.info('[Onboarding] Notification permission: $granted');

      // Mark as granted for animation (notifications are optional, so we proceed either way)
      setState(() {
        _permissionGrantedStates[Permission.notification] = granted;
      });

      // Short delay to show animation before advancing
      await Future.delayed(const Duration(milliseconds: 800));
      _goToNextPage();
      return;
    }

    // --- Permission Pages ---
    if (pageData.permission != null &&
        !pageData.isNotificationPage &&
        !kIsWeb) {
      final permission = pageData.permission!;
      final attempts = _permissionAttempts[permission] ?? 0;

      // 1. Check current status
      var status = await permission.status;
      AppLogger.debug('[Onboarding] $permission status: $status (attempt $attempts)');

      if (status.isGranted || status.isLimited) {
        // Trigger success animation
        setState(() {
          _permissionGrantedStates[permission] = true;
        });
        // Short delay to show success animation before advancing
        await Future.delayed(const Duration(milliseconds: 800));
        _goToNextPage();
        return;
      }

      // 2. First attempt: Request permission (shows system dialog if never asked)
      if (attempts == 0) {
        // Mark page as shown so auto-advance works when returning from Settings
        _shownPermissionPages.add(_currentPage);
        status = await permission.request();
        _permissionAttempts[permission] = 1;
        AppLogger.debug('[Onboarding] $permission after request: $status');

        if (status.isGranted || status.isLimited) {
          // Trigger success animation
          setState(() {
            _permissionGrantedStates[permission] = true;
          });
          // Short delay to show success animation before advancing
          await Future.delayed(const Duration(milliseconds: 800));
          _goToNextPage();
          return;
        }

        if (status.isDenied) {
          // User denied but can be asked again
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${_getPermissionName(permission)} is required. Tap again to retry.'),
              ),
            );
          }
          return;
        }
      }

      // 3. Second attempt or permanently denied: Open Settings
      if (attempts >= 1 || status.isPermanentlyDenied) {
        // Mark page as shown so auto-advance works when returning from Settings
        _shownPermissionPages.add(_currentPage);
        _permissionAttempts[permission] = attempts + 1;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Please enable ${_getPermissionName(permission)} in Settings.'),
            ),
          );
        }
        await openAppSettings();
        return;
      }
    }

    // --- Pages without permissions (should not happen in normal flow) ---
    if (pageData.permission == null && !pageData.isTermsPage) {
      _goToNextPage();
    }
  }

  String _getPermissionName(Permission permission) {
    if (permission == Permission.camera) return 'Camera';
    if (permission == Permission.location) return 'Location';
    if (permission == Permission.photos) return 'Photo Library';
    if (permission == Permission.notification) return 'Notifications';
    return 'Permission';
  }

  void _goToNextPage() {
    // Prevent duplicate navigation calls
    if (_isNavigating) {
      AppLogger.debug('[Onboarding] _goToNextPage called but already navigating, skipping');
      return;
    }

    if (_currentPage < _pages.length - 1) {
      _isNavigating = true;
      AppLogger.debug('[Onboarding] Navigating from page $_currentPage to ${_currentPage + 1}');

      _pageController
          .nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      )
          .then((_) {
        // Release lock after animation completes
        _isNavigating = false;
        AppLogger.debug('[Onboarding] Navigation complete, now on page $_currentPage');
      });
    }
  }

  void _openLegalDocument(String title, String assetPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LegalViewerScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final String imagePath;
  final Permission? permission;
  final String buttonText;
  final bool isTermsPage;
  final bool isRegistrationPage;
  final bool isNotificationPage;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.imagePath,
    this.permission,
    required this.buttonText,
    this.isTermsPage = false,
    this.isRegistrationPage = false,
    this.isNotificationPage = false,
  });
}

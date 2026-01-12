import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
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
      debugPrint('[Onboarding] App resumed. Checking permission...');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkCurrentPagePermission();
        }
      });
    }
  }

  Future<void> _checkCurrentPagePermission() async {
    // Don't check if already navigating
    if (_isNavigating) {
      debugPrint('[Onboarding] Skipping resume check - already navigating');
      return;
    }

    final pageIndexWhenCalled = _currentPage;
    final pageData = _pages[_currentPage];

    if (pageData.permission != null) {
      final status = await pageData.permission!.status;
      debugPrint('[Onboarding] Resume check: ${pageData.permission} = $status');

      // Only advance if still on the same page (prevents loop if user navigated already)
      if (status.isGranted &&
          _currentPage == pageIndexWhenCalled &&
          !_isNavigating) {
        debugPrint(
            '[Onboarding] Permission granted on resume. Advancing from page $pageIndexWhenCalled.');
        // Mark as granted for animation
        setState(() {
          _permissionGrantedStates[pageData.permission!] = true;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        _goToNextPage();
      }
    }
  }

  /// Verify all required permissions are granted before completing onboarding
  Future<bool> _verifyAllPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.location.status;
    final photosStatus = await Permission.photos.status;

    debugPrint(
        '[Onboarding] Final check: Camera=$cameraStatus, Location=$locationStatus, Photos=$photosStatus');

    return cameraStatus.isGranted &&
        locationStatus.isGranted &&
        photosStatus.isGranted;
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
                  _checkCurrentPagePermission();
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
      final allGranted = await _verifyAllPermissions();
      if (!allGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please enable Camera, Location, and Photos to continue.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      await context.read<AuthProvider>().acceptTerms();
      if (!mounted) return;
      await context.read<AuthProvider>().setOnboardingComplete();

      if (mounted && context.read<AuthProvider>().isOnboardingComplete) {
        context.go('/');
      }
      return;
    }

    // --- Permission Pages ---
    if (pageData.permission != null && !kIsWeb) {
      final permission = pageData.permission!;
      final attempts = _permissionAttempts[permission] ?? 0;

      // 1. Check current status
      var status = await permission.status;
      debugPrint(
          '[Onboarding] $permission status: $status (attempt $attempts)');

      if (status.isGranted) {
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
        status = await permission.request();
        _permissionAttempts[permission] = 1;
        debugPrint('[Onboarding] $permission after request: $status');

        if (status.isGranted) {
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
    return 'Permission';
  }

  void _goToNextPage() {
    // Prevent duplicate navigation calls
    if (_isNavigating) {
      debugPrint(
          '[Onboarding] _goToNextPage called but already navigating, skipping');
      return;
    }

    if (_currentPage < _pages.length - 1) {
      _isNavigating = true;
      debugPrint(
          '[Onboarding] Navigating from page $_currentPage to ${_currentPage + 1}');

      _pageController
          .nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      )
          .then((_) {
        // Release lock after animation completes
        _isNavigating = false;
        debugPrint(
            '[Onboarding] Navigation complete, now on page $_currentPage');
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

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.imagePath,
    this.permission,
    required this.buttonText,
    this.isTermsPage = false,
    this.isRegistrationPage = false,
  });
}

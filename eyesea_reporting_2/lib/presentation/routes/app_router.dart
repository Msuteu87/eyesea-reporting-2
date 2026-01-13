import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../home/home_screen.dart';
import '../auth/login_screen.dart';
import '../auth/sign_up_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../profile/profile_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../report/report_screen.dart';
import '../report/camera_capture_screen.dart';
import '../report/report_details_screen.dart';
import '../social_feed/social_feed_screen.dart';
import '../providers/auth_provider.dart';
import '../navigation/main_shell.dart';
import '../events/events_screen.dart';
import '../events/create_event_screen.dart';
import '../splash/splash_screen.dart';

class AppRouter {
  final AuthProvider authProvider;
  bool _splashComplete = false;
  late final GoRouter _router;

  AppRouter(this.authProvider) {
    _router = _createRouter();
  }

  static const String splash = '/splash';
  static const String home = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String profile = '/profile';
  static const String report = '/report';
  static const String cameraCapture = '/camera-capture';

  void markSplashComplete() {
    _splashComplete = true;
    // Trigger router refresh to apply redirect
    authProvider.refresh();
  }

  GoRouter get router => _router;

  GoRouter _createRouter() => GoRouter(
        initialLocation: splash,
        debugLogDiagnostics: true,
        refreshListenable: authProvider,
        redirect: (context, state) {
          final isSplash = state.uri.toString() == splash;

          // Show splash first (only once per session)
          if (!_splashComplete && !isSplash) {
            return splash;
          }

          // Stay on splash until complete
          if (isSplash && !_splashComplete) {
            return null;
          }

          // After splash, wait for auth init
          if (!authProvider.isInitialized) return null;

          final isLoggedIn = authProvider.isAuthenticated;
          final isOnboardingComplete = authProvider.isOnboardingComplete;
          final isLoggingIn = state.uri.toString() == login;
          final isOnboarding = state.uri.toString() == onboarding;
          final isSignup = state.uri.toString() == '/signup';

          // Redirect from splash after complete
          if (isSplash && _splashComplete) {
            if (!isLoggedIn) return login;
            if (!isOnboardingComplete) return onboarding;
            return home;
          }

          if (!isLoggedIn) {
            return (isLoggingIn || isSignup) ? null : login;
          }

          if (isLoggedIn && !isOnboardingComplete) {
            return isOnboarding ? null : onboarding;
          }

          if (isLoggedIn &&
              isOnboardingComplete &&
              (isLoggingIn || isOnboarding)) {
            return home;
          }

          return null;
        },
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return MainShell(navigationShell: navigationShell);
            },
            branches: [
              // 1. Home (Map)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: home,
                    name: 'home',
                    builder: (context, state) => const HomeScreen(),
                  ),
                ],
              ),
              // 2. Cleanups (Events)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/events',
                    name: 'events',
                    builder: (context, state) => const EventsScreen(),
                  ),
                ],
              ),
              // 3. Report
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: report,
                    name: 'report',
                    builder: (context, state) => const ReportScreen(),
                  ),
                ],
              ),
              // 4. Feed (Social Feed)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/feed',
                    name: 'feed',
                    builder: (context, state) => const SocialFeedScreen(),
                  ),
                ],
              ),
              // 5. Leaderboard (Profile moved to avatar in search bar)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/leaderboard',
                    name: 'leaderboard',
                    builder: (context, state) => const LeaderboardScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Auth Routes (Outside Shell)
          GoRoute(
            path: login,
            name: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/signup',
            name: 'signup',
            builder: (context, state) => const SignUpScreen(),
          ),
          GoRoute(
            path: onboarding,
            name: 'onboarding',
            builder: (context, state) {
              final user = authProvider.currentUser;
              final hasName =
                  user?.displayName != null && user!.displayName!.isNotEmpty;
              return OnboardingScreen(
                initialPage: hasName ? 1 : 0,
              );
            },
          ),

          // Splash Screen Route
          GoRoute(
            path: splash,
            name: 'splash',
            builder: (context, state) => SplashScreen(
              onComplete: () {
                markSplashComplete();
                // Force router refresh by calling go with redirect
                if (context.mounted) {
                  if (!authProvider.isAuthenticated) {
                    context.go(login);
                  } else if (!authProvider.isOnboardingComplete) {
                    context.go(onboarding);
                  } else {
                    context.go(home);
                  }
                }
              },
            ),
          ),

          // Camera Capture Route
          GoRoute(
            path: cameraCapture,
            name: 'camera-capture',
            builder: (context, state) => const CameraCaptureScreen(),
          ),

          // Report Details Route (after image capture)
          GoRoute(
            path: '/report-details',
            name: 'report-details',
            builder: (context, state) {
              final imagePath = state.uri.queryParameters['imagePath'] ?? '';
              return ReportDetailsScreen(imagePath: imagePath);
            },
          ),

          // Profile Route (accessed via avatar in search bar)
          GoRoute(
            path: profile,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),

          // Create Event Route
          GoRoute(
            path: '/create-event',
            name: 'create-event',
            builder: (context, state) => const CreateEventScreen(),
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text('Page not found: ${state.uri}'),
          ),
        ),
      );
}

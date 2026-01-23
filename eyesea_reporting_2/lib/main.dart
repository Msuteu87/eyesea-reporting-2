// TODO: [SCALABILITY] Consider using GetIt service locator for DI
// Current: 185+ lines of manual dependency injection
// Problems:
// - Hard to test (difficult to mock dependencies)
// - Hard to swap implementations (e.g., different cache backends)
// - No lazy initialization (all services created at startup)
// Fix: Use GetIt package for service registration with lazy singletons
// Example: getIt.registerLazySingleton<ConnectivityService>(() => ...)

// TODO: [SCALABILITY] Avoid ChangeNotifierProvider.value() anti-pattern
// Current: Uses .value() which doesn't manage provider lifecycle
// Risk: If provider created in one context and used in another, state mismatches
// Fix: Use create: with proper lifecycle management for better memory handling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/secrets.dart';
import 'core/utils/logger.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/profile_cache_service.dart';
import 'core/services/report_cache_service.dart';
import 'core/services/report_queue_service.dart';
import 'core/services/notification_service.dart';
import 'data/datasources/auth_data_source.dart';
import 'data/datasources/report_data_source.dart';
import 'data/datasources/social_feed_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'core/services/ai_analysis_service.dart';

import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/reports_map_provider.dart';
import 'presentation/providers/social_feed_provider.dart';
import 'presentation/providers/events_provider.dart';
import 'presentation/routes/app_router.dart';
import 'data/datasources/organization_data_source.dart';
import 'data/repositories/organization_repository_impl.dart';
import 'domain/repositories/organization_repository.dart';
import 'data/datasources/event_data_source.dart';
import 'data/repositories/event_repository_impl.dart';
import 'domain/repositories/event_repository.dart';
import 'data/datasources/badge_data_source.dart';
import 'data/datasources/leaderboard_data_source.dart';
import 'data/repositories/badge_repository_impl.dart';
import 'data/repositories/report_repository_impl.dart';
import 'data/repositories/social_feed_repository_impl.dart';
import 'domain/repositories/badge_repository.dart';
import 'domain/repositories/report_repository.dart';
import 'domain/repositories/social_feed_repository.dart';
import 'presentation/providers/profile_provider.dart';
import 'presentation/providers/leaderboard_provider.dart';
import 'presentation/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: '.env');
    AppLogger.info('Environment variables loaded from .env');
  } catch (e) {
    AppLogger.warning('Failed to load .env file: $e. Using environment variables or defaults.');
  }

  // Lock orientation to portrait mode for consistent UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Hive for offline storage
  await Hive.initFlutter();
  AppLogger.info('Hive initialized');

  // Set Mapbox access token programmatically (required for Android)
  final mapboxToken = Secrets.mapboxAccessToken;
  if (mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
    AppLogger.info('Mapbox access token configured');
  } else {
    AppLogger.warning('Mapbox access token not found. Maps may not work.');
  }

  // Load Supabase credentials from Secrets (which reads from .env or environment)
  final supabaseUrl = Secrets.supabaseUrl;
  final supabaseAnonKey = Secrets.supabaseAnonKey;

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      AppLogger.info('Supabase initialized successfully');
    } catch (e) {
      AppLogger.error('Supabase initialization failed', e);
    }
  } else {
    AppLogger.warning(
        'Supabase credentials not provided. Running in offline mode.');
  }

  final supabaseClient = Supabase.instance.client;
  final authDataSource = AuthDataSource(supabaseClient);
  final authRepository = AuthRepositoryImpl(authDataSource);

  // Initialize connectivity service first (needed by AuthProvider)
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();

  // Initialize profile cache for offline auth support
  final profileCacheService = ProfileCacheService();
  await profileCacheService.initialize();
  AppLogger.info('Profile cache service initialized');

  final authProvider = AuthProvider(
    authRepository,
    profileCacheService,
    connectivityService,
  );

  final orgDataSource = OrganizationDataSource(supabaseClient);
  final orgRepository = OrganizationRepositoryImpl(orgDataSource);

  final eventDataSource = EventDataSource(supabaseClient);
  final eventRepository = EventRepositoryImpl(eventDataSource, supabaseClient);

  final reportDataSource = ReportDataSource(supabaseClient);
  final reportRepository = ReportRepositoryImpl(reportDataSource);
  final reportQueueService =
      ReportQueueService(reportDataSource, connectivityService);
  await reportQueueService.initialize();

  // Initialize report cache service for offline caching and delta sync
  final reportCacheService = ReportCacheService();
  await reportCacheService.initialize();
  AppLogger.info('Report cache service initialized');

  final aiAnalysisService = AIAnalysisService();

  // Initialize badge repository and profile provider for gamification
  final badgeDataSource = BadgeDataSource(supabaseClient);
  final badgeRepository = BadgeRepositoryImpl(badgeDataSource);
  final profileProvider = ProfileProvider(badgeRepository, reportRepository);

  // Initialize leaderboard data source and provider
  final leaderboardDataSource = LeaderboardDataSource(supabaseClient);
  final leaderboardProvider =
      LeaderboardProvider(leaderboardDataSource, badgeDataSource);

  // Initialize notification service for realtime in-app notifications
  final notificationService = NotificationService(supabaseClient);
  await notificationService.initialize();

  // Create reports map provider for displaying markers on the map
  final reportsMapProvider = ReportsMapProvider(
    reportRepository,
    reportQueueService,
    connectivityService,
    reportCacheService,
  );

  // Create social feed repository and provider
  final socialFeedDataSource = SocialFeedDataSource(supabaseClient);
  final socialFeedRepository = SocialFeedRepositoryImpl(socialFeedDataSource);
  final socialFeedProvider = SocialFeedProvider(
    socialFeedRepository,
    connectivityService,
  );

  // Create events provider for cleanup events
  final eventsProvider = EventsProvider(eventRepository);

  // Initialize theme provider for immediate theme switching
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  final appRouter = AppRouter(authProvider);

  // Listen for PASSWORD_RECOVERY event to navigate to reset password screen
  supabaseClient.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    if (event == AuthChangeEvent.passwordRecovery) {
      AppLogger.info('Password recovery event detected - navigating to reset screen');
      // Small delay to ensure router is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        appRouter.router.go('/reset-password');
      });
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        Provider<OrganizationRepository>.value(value: orgRepository),
        Provider<EventRepository>.value(value: eventRepository),
        Provider<ReportRepository>.value(value: reportRepository),
        Provider<BadgeRepository>.value(value: badgeRepository),
        Provider<SocialFeedRepository>.value(value: socialFeedRepository),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<ReportQueueService>.value(value: reportQueueService),
        Provider<AIAnalysisService>(
          create: (_) => aiAnalysisService,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<NotificationService>(
          create: (_) => notificationService,
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<ReportsMapProvider>.value(
          value: reportsMapProvider,
        ),
        ChangeNotifierProvider<SocialFeedProvider>.value(
          value: socialFeedProvider,
        ),
        ChangeNotifierProvider<ProfileProvider>.value(
          value: profileProvider,
        ),
        ChangeNotifierProvider<EventsProvider>.value(
          value: eventsProvider,
        ),
        ChangeNotifierProvider<LeaderboardProvider>.value(
          value: leaderboardProvider,
        ),
      ],
      child: EyeseaApp(router: appRouter.router),
    ),
  );
}

SupabaseClient? get supabase {
  try {
    return Supabase.instance.client;
  } catch (e) {
    return null;
  }
}

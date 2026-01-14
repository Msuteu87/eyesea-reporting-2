import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/secrets.dart';
import 'core/utils/logger.dart';
import 'core/services/connectivity_service.dart';
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
import 'presentation/providers/profile_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline storage
  await Hive.initFlutter();
  AppLogger.info('Hive initialized');

  // Set Mapbox access token programmatically (required for Android)
  MapboxOptions.setAccessToken(Secrets.mapboxAccessToken);
  AppLogger.info('Mapbox access token configured');

  // Prefer environment variables from command line, fallback to Secrets file
  const supabaseUrlEnv = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKeyEnv = String.fromEnvironment('SUPABASE_ANON_KEY');

  final supabaseUrl =
      supabaseUrlEnv.isNotEmpty ? supabaseUrlEnv : Secrets.supabaseUrl;
  final supabaseAnonKey = supabaseAnonKeyEnv.isNotEmpty
      ? supabaseAnonKeyEnv
      : Secrets.supabaseAnonKey;

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
  final authProvider = AuthProvider(authRepository);

  final orgDataSource = OrganizationDataSource(supabaseClient);
  final orgRepository = OrganizationRepositoryImpl(orgDataSource);

  final eventDataSource = EventDataSource(supabaseClient);
  final eventRepository = EventRepositoryImpl(eventDataSource, supabaseClient);

  // Initialize connectivity and queue services
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();

  final reportDataSource = ReportDataSource(supabaseClient);
  final reportQueueService =
      ReportQueueService(reportDataSource, connectivityService);
  await reportQueueService.initialize();

  final aiAnalysisService = AIAnalysisService();

  // Initialize badge data source and profile provider for gamification
  final badgeDataSource = BadgeDataSource(supabaseClient);
  final profileProvider = ProfileProvider(badgeDataSource, reportDataSource);

  // Initialize notification service for realtime in-app notifications
  final notificationService = NotificationService(supabaseClient);
  await notificationService.initialize();

  // Create reports map provider for displaying markers on the map
  final reportsMapProvider = ReportsMapProvider(
    reportDataSource,
    reportQueueService,
    connectivityService,
  );

  // Create social feed data source and provider
  final socialFeedDataSource = SocialFeedDataSource(supabaseClient);
  final socialFeedProvider = SocialFeedProvider(
    socialFeedDataSource,
    connectivityService,
  );

  // Create events provider for cleanup events
  final eventsProvider = EventsProvider(eventRepository);

  final appRouter = AppRouter(authProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        Provider<OrganizationRepository>.value(value: orgRepository),
        Provider<EventRepository>.value(value: eventRepository),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/secrets.dart';
import 'core/utils/logger.dart';
import 'data/datasources/auth_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';

import 'presentation/providers/auth_provider.dart';
import 'presentation/routes/app_router.dart';
import 'data/datasources/organization_data_source.dart';
import 'data/repositories/organization_repository_impl.dart';
import 'domain/repositories/organization_repository.dart';
import 'data/datasources/event_data_source.dart';
import 'data/repositories/event_repository_impl.dart';
import 'domain/repositories/event_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  final appRouter = AppRouter(authProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        Provider<OrganizationRepository>.value(value: orgRepository),
        Provider<EventRepository>.value(value: eventRepository),
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

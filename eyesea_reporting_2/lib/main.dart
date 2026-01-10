import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    AppLogger.info('Supabase initialized successfully');
  } else {
    AppLogger.warning('Supabase credentials not provided. Running in offline mode.');
  }

  runApp(const EyeseaApp());
}

SupabaseClient? get supabase {
  try {
    return Supabase.instance.client;
  } catch (e) {
    return null;
  }
}

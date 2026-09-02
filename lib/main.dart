import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/network/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your project URL & anon key
  // Replace these with your actual Supabase project credentials or environment variables
  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tmckkcgymgdunakhdywj.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtY2trY2d5bWdkdW5ha2hkeXdqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNTA0NjUsImV4cCI6MjEwMzgyNjQ2NX0.-9KchXA-vhqMMF1dtUCuOW-ajb46-zbj6IL90RqBwZU',
  );

  try {
    await AppSupabaseClient.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('✅ [Supabase] Initialized successfully with endpoint: $supabaseUrl');
  } catch (e, st) {
    AppSupabaseClient.logError('App Initialization', e, st);
  }

  runApp(
    const ProviderScope(
      child: SnackTrackApp(),
    ),
  );
}

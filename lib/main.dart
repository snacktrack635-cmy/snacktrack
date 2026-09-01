import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/network/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your project URL & anon key
  // Replace these with your actual Supabase project credentials or environment variables
  const supabaseUrl = String.fromEnvironment(
    'https://tmckkcgymgdunakhdywj.supabase.co/rest/v1/',
    defaultValue: 'https://xyzcompany.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtY2trY2d5bWdkdW5ha2hkeXdqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNTA0NjUsImV4cCI6MjEwMzgyNjQ2NX0.-9KchXA-vhqMMF1dtUCuOW-ajb46-zbj6IL90RqBwZU',
    defaultValue: 'public-anon-key',
  );

  try {
    await AppSupabaseClient.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization notice: $e');
  }

  runApp(
    const ProviderScope(
      child: SnackTrackApp(),
    ),
  );
}

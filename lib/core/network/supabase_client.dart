import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabaseClient {
  AppSupabaseClient._();

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static String? get currentUserId => client.auth.currentUser?.id;

  static bool get isAuthenticated => client.auth.currentUser != null;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      // ignore: deprecated_member_use
      anonKey: anonKey,
    );

    // Automatically establish session for RLS-protected tables
    await ensureAuthenticated();
  }

  /// Ensures an active user session exists so RLS-protected tables (like pantry_items)
  /// can be queried and updated with a valid auth.uid().
  static Future<void> ensureAuthenticated() async {
    try {
      if (client.auth.currentUser == null) {
        await client.auth.signInAnonymously();
        debugPrint('✅ [Supabase Auth] Anonymous session created: ${client.auth.currentUser?.id}');
      }

      final user = client.auth.currentUser;
      if (user != null) {
        // Ensure a profile record exists for foreign-key constraints
        await client.from('profiles').upsert({'id': user.id}).select().maybeSingle();
      }
    } catch (e, st) {
      debugPrint('⚠️ [Supabase Auth] Could not ensure authenticated session: $e');
      logError('ensureAuthenticated', e, st);
    }
  }

  /// Convenience wrapper for Edge Function invocations with detailed error printing
  static Future<FunctionResponse> invokeFunction(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await client.functions.invoke(
        functionName,
        body: body,
        headers: headers,
      );

      if (response.status >= 400) {
        debugPrint(
          '❌ [Supabase Edge Function Error] "$functionName" returned status ${response.status}\n'
          '  Data: ${response.data}',
        );
      } else {
        debugPrint('✅ [Supabase Edge Function Success] "$functionName" (status ${response.status})');
      }

      return response;
    } catch (e, st) {
      logError('invokeFunction ("$functionName")', e, st);
      rethrow;
    }
  }

  /// Centralized formatter and logger for all Supabase errors
  static void logError(String operation, dynamic error, [StackTrace? stackTrace]) {
    final buffer = StringBuffer();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('❌ [Supabase Error] Operation: $operation');

    if (error is PostgrestException) {
      buffer.writeln('  Kind: PostgrestException (Database query failed)');
      buffer.writeln('  Message: ${error.message}');
      if (error.code != null) buffer.writeln('  Code: ${error.code}');
      if (error.details != null) buffer.writeln('  Details: ${error.details}');
      if (error.hint != null) buffer.writeln('  Hint: ${error.hint}');
    } else if (error is FunctionException) {
      buffer.writeln('  Kind: FunctionException (Edge function failed)');
      buffer.writeln('  Status: ${error.status}');
      buffer.writeln('  Details: ${error.details}');
      if (error.reasonPhrase != null) buffer.writeln('  Reason: ${error.reasonPhrase}');
    } else if (error is AuthException) {
      buffer.writeln('  Kind: AuthException (Authentication failed)');
      buffer.writeln('  Status: ${error.statusCode}');
      buffer.writeln('  Message: ${error.message}');
    } else {
      buffer.writeln('  Kind: ${error.runtimeType}');
      buffer.writeln('  Message: $error');
    }

    if (stackTrace != null) {
      buffer.writeln('  StackTrace:\n$stackTrace');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    debugPrint(buffer.toString());
  }
}

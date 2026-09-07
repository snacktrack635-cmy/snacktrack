import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppSupabaseClient.logError', () {
    test('logs PostgrestException without crashing', () {
      const pgError = PostgrestException(
        message: 'relation "pantry_items" does not exist',
        code: '42P01',
        details: 'table missing',
        hint: 'check database schema',
      );

      expect(
        () => AppSupabaseClient.logError('testQuery', pgError, StackTrace.current),
        returnsNormally,
      );
    });

    test('logs FunctionException without crashing', () {
      final fnError = FunctionException(
        status: 429,
        details: {'error': 'Quota exceeded'},
        reasonPhrase: 'Too Many Requests',
      );

      expect(
        () => AppSupabaseClient.logError('testFunction', fnError),
        returnsNormally,
      );
    });

    test('logs AuthException without crashing', () {
      const authError = AuthException('Invalid login token', statusCode: '401');

      expect(
        () => AppSupabaseClient.logError('testAuth', authError, StackTrace.current),
        returnsNormally,
      );
    });

    test('logs arbitrary exception without crashing', () {
      final genericError = Exception('Unexpected network drop');

      expect(
        () => AppSupabaseClient.logError('genericOp', genericError),
        returnsNormally,
      );
    });

    test('logs string error without crashing', () {
      expect(
        () => AppSupabaseClient.logError('stringOp', 'Simple string error'),
        returnsNormally,
      );
    });
  });
}

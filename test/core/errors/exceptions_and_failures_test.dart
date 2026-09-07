import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/errors/exceptions.dart';
import 'package:snacktrack/core/errors/failures.dart';

void main() {
  group('AppExceptions', () {
    test('AppException toString formats correctly with and without code', () {
      const exNoCode = AppException('General error occurred');
      expect(exNoCode.toString(), equals('AppException: General error occurred'));
      expect(exNoCode.message, equals('General error occurred'));
      expect(exNoCode.code, isNull);

      const exWithCode = AppException('Database error', code: '404');
      expect(exWithCode.toString(), equals('AppException: Database error (code: 404)'));
      expect(exWithCode.code, equals('404'));
    });

    test('ServerException formats with code', () {
      const ex = ServerException('Internal Server Error', code: '500');
      expect(ex.toString(), equals('ServerException: Internal Server Error (code: 500)'));
      expect(ex, isA<AppException>());
      expect(ex, isA<Exception>());
    });

    test('NetworkException formats correctly', () {
      const ex = NetworkException('Socket timeout');
      expect(ex.toString(), equals('NetworkException: Socket timeout'));
      expect(ex, isA<AppException>());
    });

    test('AuthException formats correctly', () {
      const ex = AuthException('Invalid credentials', code: '401');
      expect(ex.toString(), equals('AuthException: Invalid credentials (code: 401)'));
      expect(ex, isA<AppException>());
    });

    test('QuotaExceededException formats correctly', () {
      const ex = QuotaExceededException('Monthly scan quota exceeded', code: '429');
      expect(ex.toString(), equals('QuotaExceededException: Monthly scan quota exceeded (code: 429)'));
      expect(ex, isA<AppException>());
    });

    test('ScanException formats correctly', () {
      const ex = ScanException('Unrecognized barcode');
      expect(ex.toString(), equals('ScanException: Unrecognized barcode'));
      expect(ex, isA<AppException>());
    });
  });

  group('Failures', () {
    test('ServerFailure formats correctly with and without code', () {
      const f1 = ServerFailure('Server unreachable');
      expect(f1.toString(), equals('ServerFailure(message: Server unreachable, code: null)'));
      expect(f1.message, equals('Server unreachable'));
      expect(f1.code, isNull);

      const f2 = ServerFailure('Timeout', code: '504');
      expect(f2.toString(), equals('ServerFailure(message: Timeout, code: 504)'));
    });

    test('NetworkFailure formats correctly', () {
      const f = NetworkFailure('No internet connection');
      expect(f.toString(), equals('NetworkFailure(message: No internet connection, code: null)'));
      expect(f, isA<Failure>());
    });

    test('AuthFailure formats correctly', () {
      const f = AuthFailure('Unauthorized', code: '403');
      expect(f.toString(), equals('AuthFailure(message: Unauthorized, code: 403)'));
      expect(f, isA<Failure>());
    });

    test('QuotaExceededFailure formats correctly', () {
      const f = QuotaExceededFailure('Rate limit exceeded', code: '429');
      expect(f.toString(), equals('QuotaExceededFailure(message: Rate limit exceeded, code: 429)'));
      expect(f, isA<Failure>());
    });

    test('ScanFailure formats correctly', () {
      const f = ScanFailure('Blurry image');
      expect(f.toString(), equals('ScanFailure(message: Blurry image, code: null)'));
      expect(f, isA<Failure>());
    });

    test('CacheFailure formats correctly', () {
      const f = CacheFailure('Cache miss');
      expect(f.toString(), equals('CacheFailure(message: Cache miss, code: null)'));
      expect(f, isA<Failure>());
    });
  });
}

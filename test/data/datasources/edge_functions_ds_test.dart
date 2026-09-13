import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/errors/exceptions.dart';
import 'package:snacktrack/data/datasources/edge_functions_ds.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeFunctionsClient implements FunctionsClient {
  dynamic errorToThrow;
  FunctionResponse? responseToReturn;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #invoke) {
      if (errorToThrow != null) {
        throw errorToThrow;
      }
      return Future.value(
        responseToReturn ??
            FunctionResponse(
              data: {
                'recipe': {
                  'id': 'r-1',
                  'name': 'Pasta',
                  'ingredients': [
                    {'name': 'Tomato'}
                  ],
                  'instructions': ['Cook it.'],
                },
              },
              status: 200,
            ),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeSupabaseClient implements SupabaseClient {
  final FakeFunctionsClient _functions;

  FakeSupabaseClient(this._functions);

  @override
  FunctionsClient get functions => _functions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('EdgeFunctionsDataSource error handling', () {
    late FakeFunctionsClient fakeFunctions;
    late FakeSupabaseClient fakeClient;
    late EdgeFunctionsDataSource dataSource;

    setUp(() {
      fakeFunctions = FakeFunctionsClient();
      fakeClient = FakeSupabaseClient(fakeFunctions);
      dataSource = EdgeFunctionsDataSource(fakeClient);
    });

    test('generateRecipe maps FunctionsHttpException 403 quota_exceeded to QuotaExceededException', () async {
      fakeFunctions.errorToThrow = FunctionException(
        status: 403,
        details: {
          'error': 'quota_exceeded',
          'message': 'Monthly recipe generation limit reached.',
        },
        reasonPhrase: 'Forbidden',
      );

      expect(
        () => dataSource.generateRecipe(primaryIngredient: 'Pasta'),
        throwsA(
          isA<QuotaExceededException>().having(
            (e) => e.message,
            'message',
            equals('Your monthly quota has been reached.'),
          ),
        ),
      );
    });

    test('generateRecipe maps FunctionException 429 to QuotaExceededException', () async {
      fakeFunctions.errorToThrow = FunctionException(
        status: 429,
        details: {'error': 'Too many requests'},
        reasonPhrase: 'Too Many Requests',
      );

      expect(
        () => dataSource.generateRecipe(primaryIngredient: 'Pasta'),
        throwsA(isA<QuotaExceededException>()),
      );
    });

    test('generateRecipe maps non-quota FunctionException to clean ServerException', () async {
      fakeFunctions.errorToThrow = FunctionException(
        status: 500,
        details: {'error': 'Internal server error in model execution'},
        reasonPhrase: 'Internal Server Error',
      );

      expect(
        () => dataSource.generateRecipe(primaryIngredient: 'Pasta'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            equals('Internal server error in model execution'),
          ),
        ),
      );
    });

    test('generateExpiringSoonRecipe maps FunctionsHttpException 403 quota_exceeded to QuotaExceededException', () async {
      fakeFunctions.errorToThrow = FunctionException(
        status: 403,
        details: {
          'error': 'quota_exceeded',
          'message': 'Monthly recipe generation limit reached.',
        },
        reasonPhrase: 'Forbidden',
      );

      expect(
        () => dataSource.generateExpiringSoonRecipe(expiringItems: ['Milk']),
        throwsA(
          isA<QuotaExceededException>().having(
            (e) => e.message,
            'message',
            equals('Your monthly quota has been reached.'),
          ),
        ),
      );
    });

    test('scanFoodItemWithAi maps 429 to QuotaExceededException with scan-specific message', () async {
      fakeFunctions.errorToThrow = FunctionException(
        status: 429,
        details: {'error': 'Monthly scan limit exceeded'},
        reasonPhrase: 'Too Many Requests',
      );

      expect(
        () => dataSource.scanFoodItemWithAi(imageBase64: 'abc'),
        throwsA(
          isA<QuotaExceededException>().having(
            (e) => e.message,
            'message',
            contains('Monthly AI food scan quota exceeded'),
          ),
        ),
      );
    });
  });
}

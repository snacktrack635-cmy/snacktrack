import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/constants/tier_limits.dart';
import 'package:snacktrack/data/repositories/subscription_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StubSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SubscriptionRepository.canScan and canGenerateRecipe', () {
    late SubscriptionRepository repository;

    setUp(() {
      repository = SubscriptionRepository(StubSupabaseClient());
    });

    test('canScan returns true for Pro tier regardless of usage', () async {
      expect(await repository.canScan(SubscriptionTier.pro, 0), isTrue);
      expect(await repository.canScan(SubscriptionTier.pro, 999), isTrue);
    });

    test('canScan enforces Free tier limit (3)', () async {
      expect(await repository.canScan(SubscriptionTier.free, 0), isTrue);
      expect(await repository.canScan(SubscriptionTier.free, 2), isTrue);
      expect(await repository.canScan(SubscriptionTier.free, 3), isFalse);
      expect(await repository.canScan(SubscriptionTier.free, 10), isFalse);
    });

    test('canScan enforces Plus tier limit (50)', () async {
      expect(await repository.canScan(SubscriptionTier.plus, 0), isTrue);
      expect(await repository.canScan(SubscriptionTier.plus, 49), isTrue);
      expect(await repository.canScan(SubscriptionTier.plus, 50), isFalse);
    });

    test('canGenerateRecipe returns true for Pro tier regardless of usage', () async {
      expect(await repository.canGenerateRecipe(SubscriptionTier.pro, 0), isTrue);
      expect(await repository.canGenerateRecipe(SubscriptionTier.pro, 500), isTrue);
    });

    test('canGenerateRecipe enforces Free tier limit (5)', () async {
      expect(await repository.canGenerateRecipe(SubscriptionTier.free, 0), isTrue);
      expect(await repository.canGenerateRecipe(SubscriptionTier.free, 4), isTrue);
      expect(await repository.canGenerateRecipe(SubscriptionTier.free, 5), isFalse);
    });

    test('canGenerateRecipe enforces Plus tier limit (30)', () async {
      expect(await repository.canGenerateRecipe(SubscriptionTier.plus, 0), isTrue);
      expect(await repository.canGenerateRecipe(SubscriptionTier.plus, 29), isTrue);
      expect(await repository.canGenerateRecipe(SubscriptionTier.plus, 30), isFalse);
    });
  });
}

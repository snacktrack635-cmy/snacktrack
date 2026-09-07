import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/constants/tier_limits.dart';
import 'package:snacktrack/data/models/subscription.dart';

void main() {
  group('UserSubscription', () {
    test('fromJson parses free, plus, and pro tiers', () {
      final jsonFree = {'id': 's-1', 'user_id': 'u-1', 'tier': 'free'};
      expect(UserSubscription.fromJson(jsonFree).tier, equals(SubscriptionTier.free));

      final jsonPlus = {'id': 's-2', 'user_id': 'u-2', 'tier': 'plus'};
      expect(UserSubscription.fromJson(jsonPlus).tier, equals(SubscriptionTier.plus));

      final jsonPro = {'id': 's-3', 'user_id': 'u-3', 'tier': 'pro'};
      expect(UserSubscription.fromJson(jsonPro).tier, equals(SubscriptionTier.pro));

      final jsonUnknown = {'id': 's-4', 'user_id': 'u-4', 'tier': 'enterprise'};
      expect(UserSubscription.fromJson(jsonUnknown).tier, equals(SubscriptionTier.free));

      final jsonNull = {'id': 's-5', 'user_id': 'u-5'};
      expect(UserSubscription.fromJson(jsonNull).tier, equals(SubscriptionTier.free));
    });

    test('fromJson parses subscription providers correctly', () {
      final jsonStripe = {'id': 's-1', 'user_id': 'u-1', 'provider': 'stripe'};
      expect(UserSubscription.fromJson(jsonStripe).provider, equals(SubscriptionProvider.stripe));

      final jsonApple = {'id': 's-2', 'user_id': 'u-2', 'provider': 'apple'};
      expect(UserSubscription.fromJson(jsonApple).provider, equals(SubscriptionProvider.apple));

      final jsonGoogle = {'id': 's-3', 'user_id': 'u-3', 'provider': 'google'};
      expect(UserSubscription.fromJson(jsonGoogle).provider, equals(SubscriptionProvider.google));

      final jsonUnknown = {'id': 's-4', 'user_id': 'u-4', 'provider': 'paypal'};
      expect(UserSubscription.fromJson(jsonUnknown).provider, isNull);
    });

    test('isActive getter checks active status', () {
      final subActive = UserSubscription(
        id: 's-1',
        userId: 'u-1',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(subActive.isActive, isTrue);

      final subExpired = UserSubscription(
        id: 's-2',
        userId: 'u-1',
        status: 'canceled',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(subExpired.isActive, isFalse);
    });

    test('toJson serializes UserSubscription correctly', () {
      final now = DateTime(2026, 9, 1);
      final sub = UserSubscription(
        id: 's-10',
        userId: 'u-20',
        tier: SubscriptionTier.plus,
        provider: SubscriptionProvider.stripe,
        providerSubscriptionId: 'sub_xyz123',
        status: 'active',
        currentPeriodEnd: DateTime(2026, 10, 1),
        createdAt: now,
        updatedAt: now,
      );

      final json = sub.toJson();
      expect(json['id'], equals('s-10'));
      expect(json['user_id'], equals('u-20'));
      expect(json['tier'], equals('plus'));
      expect(json['provider'], equals('stripe'));
      expect(json['provider_subscription_id'], equals('sub_xyz123'));
      expect(json['status'], equals('active'));
    });
  });

  group('UsageCounter', () {
    test('fromJson and toJson round-trip', () {
      final now = DateTime(2026, 9, 1);
      final json = {
        'user_id': 'u-100',
        'period_start': now.toIso8601String(),
        'scans_used': 15,
        'recipes_generated': 7,
      };

      final counter = UsageCounter.fromJson(json);
      expect(counter.userId, equals('u-100'));
      expect(counter.scansUsed, equals(15));
      expect(counter.recipesGenerated, equals(7));

      final serialized = counter.toJson();
      expect(serialized['user_id'], equals('u-100'));
      expect(serialized['scans_used'], equals(15));
      expect(serialized['recipes_generated'], equals(7));
    });

    test('copyWith updates fields as expected', () {
      final counter = UsageCounter(
        userId: 'u-1',
        periodStart: DateTime.now(),
        scansUsed: 2,
        recipesGenerated: 1,
      );

      final updated = counter.copyWith(scansUsed: 3);
      expect(updated.scansUsed, equals(3));
      expect(updated.recipesGenerated, equals(1));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/constants/tier_limits.dart';
import 'package:snacktrack/data/models/subscription.dart';
import 'package:snacktrack/features/subscription/application/subscription_controller.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('SubscriptionController', () {
    late FakeSubscriptionRepository repository;
    late SubscriptionController controller;

    setUp(() {
      repository = FakeSubscriptionRepository();
      controller = SubscriptionController(repository);
    });

    test('initial state loads subscription and usage counter', () async {
      await controller.loadSubscription();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.subscription, isNotNull);
      expect(controller.state.currentTier, equals(SubscriptionTier.free));
      expect(controller.state.usageCounter, isNotNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('loadSubscription sets errorMessage when repository fails', () async {
      repository.throwOnGetSubscription = true;
      repository.errorMessage = 'Network failure';

      await controller.loadSubscription();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, contains('Failed to load subscription details'));
    });

    test('scansRemaining and recipesRemaining calculate correctly for Free tier', () async {
      repository.subscription = UserSubscription(
        id: 's-1',
        userId: 'u-1',
        tier: SubscriptionTier.free,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      repository.usageCounter = UsageCounter(
        userId: 'u-1',
        periodStart: DateTime.now(),
        scansUsed: 1,
        recipesGenerated: 2,
      );

      await controller.loadSubscription();

      // Free tier: 3 scans limit - 1 used = 2 remaining
      expect(controller.state.scansRemaining, equals(2));
      // Free tier: 5 recipes limit - 2 used = 3 remaining
      expect(controller.state.recipesRemaining, equals(3));
    });

    test('scansRemaining and recipesRemaining clamp to 0 when usage exceeds limit', () async {
      repository.subscription = UserSubscription(
        id: 's-1',
        userId: 'u-1',
        tier: SubscriptionTier.free,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      repository.usageCounter = UsageCounter(
        userId: 'u-1',
        periodStart: DateTime.now(),
        scansUsed: 10,
        recipesGenerated: 20,
      );

      await controller.loadSubscription();

      expect(controller.state.scansRemaining, equals(0));
      expect(controller.state.recipesRemaining, equals(0));
    });

    test('scansRemaining and recipesRemaining return -1 for Pro tier (unlimited)', () async {
      repository.subscription = UserSubscription(
        id: 's-pro',
        userId: 'u-1',
        tier: SubscriptionTier.pro,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      repository.usageCounter = UsageCounter(
        userId: 'u-1',
        periodStart: DateTime.now(),
        scansUsed: 100,
        recipesGenerated: 50,
      );

      await controller.loadSubscription();

      expect(controller.state.scansRemaining, equals(-1));
      expect(controller.state.recipesRemaining, equals(-1));
    });

    test('upgradeToTier simulates upgrade flow successfully', () async {
      final upgradeFuture = controller.upgradeToTier(SubscriptionTier.plus);
      expect(controller.state.isUpgrading, isTrue);

      await upgradeFuture;

      expect(controller.state.isUpgrading, isFalse);
      expect(controller.state.errorMessage, isNull);
    });
  });
}

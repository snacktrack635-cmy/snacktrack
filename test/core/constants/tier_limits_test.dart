import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/constants/tier_limits.dart';

void main() {
  group('TierLimits', () {
    test('constants have expected values', () {
      expect(TierLimits.freeScanLimit, equals(3));
      expect(TierLimits.plusScanLimit, equals(50));
      expect(TierLimits.proScanLimit, equals(-1));

      expect(TierLimits.freeRecipeGenerations, equals(5));
      expect(TierLimits.plusRecipeGenerations, equals(30));
      expect(TierLimits.proRecipeGenerations, equals(-1));
    });

    test('allowsBatchScanning correctly reflects tier privileges', () {
      expect(TierLimits.allowsBatchScanning(SubscriptionTier.free), isFalse);
      expect(TierLimits.allowsBatchScanning(SubscriptionTier.plus), isTrue);
      expect(TierLimits.allowsBatchScanning(SubscriptionTier.pro), isTrue);
    });

    test('getScanLimit returns correct limits per tier', () {
      expect(TierLimits.getScanLimit(SubscriptionTier.free), equals(3));
      expect(TierLimits.getScanLimit(SubscriptionTier.plus), equals(50));
      expect(TierLimits.getScanLimit(SubscriptionTier.pro), equals(-1));
    });

    test('getRecipeLimit returns correct limits per tier', () {
      expect(TierLimits.getRecipeLimit(SubscriptionTier.free), equals(5));
      expect(TierLimits.getRecipeLimit(SubscriptionTier.plus), equals(30));
      expect(TierLimits.getRecipeLimit(SubscriptionTier.pro), equals(-1));
    });

    test('isUnlimitedScans is only true for pro tier', () {
      expect(TierLimits.isUnlimitedScans(SubscriptionTier.free), isFalse);
      expect(TierLimits.isUnlimitedScans(SubscriptionTier.plus), isFalse);
      expect(TierLimits.isUnlimitedScans(SubscriptionTier.pro), isTrue);
    });

    test('isUnlimitedRecipes is only true for pro tier', () {
      expect(TierLimits.isUnlimitedRecipes(SubscriptionTier.free), isFalse);
      expect(TierLimits.isUnlimitedRecipes(SubscriptionTier.plus), isFalse);
      expect(TierLimits.isUnlimitedRecipes(SubscriptionTier.pro), isTrue);
    });
  });
}

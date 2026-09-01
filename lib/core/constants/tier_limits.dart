enum SubscriptionTier {
  free,
  plus,
  pro,
}

class TierLimits {
  TierLimits._();

  static const int freeScanLimit = 3;
  static const int plusScanLimit = 50;
  static const int proScanLimit = -1; // -1 represents unlimited

  static const int freeRecipeGenerations = 5;
  static const int plusRecipeGenerations = 30;
  static const int proRecipeGenerations = -1; // Unlimited

  static bool allowsBatchScanning(SubscriptionTier tier) {
    return tier != SubscriptionTier.free;
  }

  static int getScanLimit(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return freeScanLimit;
      case SubscriptionTier.plus:
        return plusScanLimit;
      case SubscriptionTier.pro:
        return proScanLimit;
    }
  }

  static int getRecipeLimit(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return freeRecipeGenerations;
      case SubscriptionTier.plus:
        return plusRecipeGenerations;
      case SubscriptionTier.pro:
        return proRecipeGenerations;
    }
  }

  static bool isUnlimitedScans(SubscriptionTier tier) => tier == SubscriptionTier.pro;
  static bool isUnlimitedRecipes(SubscriptionTier tier) => tier == SubscriptionTier.pro;
}

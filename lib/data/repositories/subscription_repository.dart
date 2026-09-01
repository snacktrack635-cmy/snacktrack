import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snacktrack/core/constants/app_constants.dart';
import 'package:snacktrack/data/models/subscription.dart';

class SubscriptionRepository {
  final SupabaseClient _client;

  SubscriptionRepository(this._client);

  Future<UserSubscription> getSubscription() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return UserSubscription(
        id: '',
        userId: '',
        tier: SubscriptionTier.free,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    final response = await _client
        .from(AppConstants.subscriptionsTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return UserSubscription(
        id: '',
        userId: userId,
        tier: SubscriptionTier.free,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return UserSubscription.fromJson(response);
  }

  Future<UsageCounter> getUsageCounters() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return UsageCounter(
        userId: '',
        periodStart: DateTime.now(),
      );
    }

    final response = await _client
        .from(AppConstants.usageCountersTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return UsageCounter(
        userId: userId,
        periodStart: DateTime.now(),
      );
    }

    return UsageCounter.fromJson(response);
  }

  Future<bool> canScan(SubscriptionTier tier, int currentScans) async {
    if (TierLimits.isUnlimitedScans(tier)) return true;
    final limit = TierLimits.getScanLimit(tier);
    return currentScans < limit;
  }

  Future<bool> canGenerateRecipe(SubscriptionTier tier, int currentGenerations) async {
    if (TierLimits.isUnlimitedRecipes(tier)) return true;
    final limit = TierLimits.getRecipeLimit(tier);
    return currentGenerations < limit;
  }

  Future<void> incrementScanUsage() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.rpc('increment_usage_scans', params: {'p_user_id': userId});
  }
}

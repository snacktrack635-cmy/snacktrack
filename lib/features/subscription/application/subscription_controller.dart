import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tier_limits.dart';
import '../../../data/models/subscription.dart';
import '../../../data/repositories/subscription_repository.dart';
import '../../../providers/global_providers.dart';

class SubscriptionState {
  final UserSubscription? subscription;
  final UsageCounter? usageCounter;
  final bool isLoading;
  final String? errorMessage;
  final bool isUpgrading;

  const SubscriptionState({
    this.subscription,
    this.usageCounter,
    this.isLoading = false,
    this.errorMessage,
    this.isUpgrading = false,
  });

  SubscriptionTier get currentTier => subscription?.tier ?? SubscriptionTier.free;

  int get scansRemaining {
    if (TierLimits.isUnlimitedScans(currentTier)) return -1;
    final limit = TierLimits.getScanLimit(currentTier);
    final used = usageCounter?.scansUsed ?? 0;
    return (limit - used).clamp(0, limit);
  }

  int get recipesRemaining {
    if (TierLimits.isUnlimitedRecipes(currentTier)) return -1;
    final limit = TierLimits.getRecipeLimit(currentTier);
    final used = usageCounter?.recipesGenerated ?? 0;
    return (limit - used).clamp(0, limit);
  }

  SubscriptionState copyWith({
    UserSubscription? subscription,
    UsageCounter? usageCounter,
    bool? isLoading,
    String? errorMessage,
    bool? isUpgrading,
  }) {
    return SubscriptionState(
      subscription: subscription ?? this.subscription,
      usageCounter: usageCounter ?? this.usageCounter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isUpgrading: isUpgrading ?? this.isUpgrading,
    );
  }
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  final SubscriptionRepository _repository;

  SubscriptionController(this._repository) : super(const SubscriptionState()) {
    loadSubscription();
  }

  Future<void> loadSubscription() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final sub = await _repository.getSubscription();
      final usage = await _repository.getUsageCounters();
      state = state.copyWith(
        subscription: sub,
        usageCounter: usage,
        isLoading: false,
      );
    } catch (e, st) {
      debugPrint('❌ [SubscriptionController.loadSubscription] Error: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load subscription details: $e',
      );
    }
  }

  Future<void> upgradeToTier(SubscriptionTier tier) async {
    state = state.copyWith(isUpgrading: true, errorMessage: null);
    try {
      // In production, launches Stripe checkout session / in-app purchase flow
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(isUpgrading: false);
    } catch (e, st) {
      debugPrint('❌ [SubscriptionController.upgradeToTier] Error: $e\n$st');
      state = state.copyWith(
        isUpgrading: false,
        errorMessage: 'Upgrade failed: $e',
      );
    }
  }
}

final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>((ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return SubscriptionController(repo);
});

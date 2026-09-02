import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snacktrack/data/datasources/edge_functions_ds.dart';
import 'package:snacktrack/providers/global_providers.dart';

class OnboardingState {
  final bool isLoading;
  final bool hasCompletedOnboarding;
  final int loginCount;
  final int currentPageIndex;

  const OnboardingState({
    this.isLoading = false,
    this.hasCompletedOnboarding = false,
    this.loginCount = 0,
    this.currentPageIndex = 0,
  });

  OnboardingState copyWith({
    bool? isLoading,
    bool? hasCompletedOnboarding,
    int? loginCount,
    int? currentPageIndex,
  }) {
    return OnboardingState(
      isLoading: isLoading ?? this.isLoading,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      loginCount: loginCount ?? this.loginCount,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  final EdgeFunctionsDataSource _edgeFunctions;

  OnboardingController(this._edgeFunctions) : super(const OnboardingState());

  void setPageIndex(int index) {
    state = state.copyWith(currentPageIndex: index);
  }

  Future<void> recordAppSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final count = await _edgeFunctions.incrementSession();
      state = state.copyWith(
        isLoading: false,
        loginCount: count,
        hasCompletedOnboarding: count > 1,
      );
    } catch (e, st) {
      debugPrint('❌ [OnboardingController.recordAppSession] Failed: $e\n$st');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(hasCompletedOnboarding: true);
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  final edgeFunctions = ref.watch(edgeFunctionsDataSourceProvider);
  return OnboardingController(edgeFunctions);
});

import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/features/onboarding/application/onboarding_controller.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('OnboardingController', () {
    late FakeEdgeFunctionsDataSource fakeEdgeFunctions;
    late OnboardingController controller;

    setUp(() {
      fakeEdgeFunctions = FakeEdgeFunctionsDataSource();
      controller = OnboardingController(fakeEdgeFunctions);
    });

    test('initial state has correct defaults', () {
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.hasCompletedOnboarding, isFalse);
      expect(controller.state.loginCount, equals(0));
      expect(controller.state.currentPageIndex, equals(0));
    });

    test('setPageIndex updates currentPageIndex', () {
      controller.setPageIndex(2);
      expect(controller.state.currentPageIndex, equals(2));
    });

    test('recordAppSession marks completed when loginCount > 1', () async {
      fakeEdgeFunctions.sessionCount = 3;

      await controller.recordAppSession();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.loginCount, equals(3));
      expect(controller.state.hasCompletedOnboarding, isTrue);
    });

    test('recordAppSession keeps hasCompletedOnboarding false on first session', () async {
      fakeEdgeFunctions.sessionCount = 1;

      await controller.recordAppSession();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.loginCount, equals(1));
      expect(controller.state.hasCompletedOnboarding, isFalse);
    });

    test('recordAppSession handles errors gracefully without throwing', () async {
      fakeEdgeFunctions.throwOnSession = true;

      await controller.recordAppSession();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.loginCount, equals(0));
      expect(controller.state.hasCompletedOnboarding, isFalse);
    });

    test('completeOnboarding sets hasCompletedOnboarding to true', () async {
      await controller.completeOnboarding();
      expect(controller.state.hasCompletedOnboarding, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/features/onboarding/application/onboarding_controller.dart';
import 'package:snacktrack/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:snacktrack/features/onboarding/presentation/widgets/onboarding_carousel_item.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('Onboarding Presentation', () {
    late FakeEdgeFunctionsDataSource edgeFunctions;

    setUp(() {
      edgeFunctions = FakeEdgeFunctionsDataSource();
    });

    testWidgets('OnboardingCarouselItem renders slide details', (tester) async {
      const slide = OnboardingSlide(
        title: 'Track Groceries',
        description: 'Keep food fresh and reduce waste.',
        icon: Icons.kitchen,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OnboardingCarouselItem(slide: slide),
          ),
        ),
      );

      expect(find.text('Track Groceries'), findsOneWidget);
      expect(find.text('Keep food fresh and reduce waste.'), findsOneWidget);
      expect(find.byIcon(Icons.kitchen), findsOneWidget);
    });

    testWidgets('OnboardingScreen renders first slide and advances with Next button', (tester) async {
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/subscription/paywall',
            builder: (context, state) => const Scaffold(body: Text('Paywall Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingControllerProvider.overrideWith(
              (ref) => OnboardingController(edgeFunctions),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      // Slide 1 is visible
      expect(find.text('Track Your Pantry Effortlessly'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next to advance
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Slide 2 is visible
      expect(find.text('AI Recipe Suggestions'), findsOneWidget);

      // Tap Next to advance to Slide 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Last slide shows Get Started
      expect(find.text('Smart Shopping & Zero Waste'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Tap Get Started navigates to paywall
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('Paywall Target'), findsOneWidget);
    });

    testWidgets('OnboardingScreen Skip button navigates directly to paywall', (tester) async {
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/subscription/paywall',
            builder: (context, state) => const Scaffold(body: Text('Paywall Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingControllerProvider.overrideWith(
              (ref) => OnboardingController(edgeFunctions),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Paywall Target'), findsOneWidget);
    });
  });
}

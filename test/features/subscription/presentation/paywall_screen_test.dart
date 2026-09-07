import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/features/subscription/application/subscription_controller.dart';
import 'package:snacktrack/features/subscription/presentation/screens/paywall_screen.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('PaywallScreen', () {
    late FakeSubscriptionRepository repository;

    setUp(() {
      repository = FakeSubscriptionRepository();
    });

    Widget createTestWidget() {
      final router = GoRouter(
        initialLocation: '/subscription/paywall',
        routes: [
          GoRoute(
            path: '/subscription/paywall',
            builder: (context, state) => const PaywallScreen(),
          ),
          GoRoute(
            path: '/pantry',
            builder: (context, state) => const Scaffold(body: Text('Pantry Screen')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          subscriptionControllerProvider.overrideWith(
            (ref) => SubscriptionController(repository),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('renders all subscription tier options and features', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Unlock Full Pantry Superpowers'), findsOneWidget);
      expect(find.text('Free Tier'), findsOneWidget);
      expect(find.text('Plus Tier'), findsOneWidget);
      expect(find.text('Pro Tier'), findsOneWidget);
      expect(find.text('\$0 / month'), findsOneWidget);
      expect(find.text('\$4.99 / month'), findsOneWidget);
      expect(find.text('\$9.99 / month'), findsOneWidget);
    });

    testWidgets('selecting a tier card updates the subscribe button label', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Plus is selected by default
      expect(find.text('Subscribe to PLUS'), findsOneWidget);

      // Tap Pro tier
      await tester.tap(find.text('Pro Tier'));
      await tester.pumpAndSettle();

      expect(find.text('Subscribe to PRO'), findsOneWidget);
    });

    testWidgets('subscribing triggers upgrade and shows confirmation snackbar', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subscribe to PLUS'));
      await tester.pump();

      // Pump through the simulated upgrade delay
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Subscribed to PLUS!'), findsOneWidget);
      expect(find.text('Pantry Screen'), findsOneWidget);
    });

    testWidgets('Continue with Free Tier navigates to pantry', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Free Tier'));
      await tester.pumpAndSettle();

      expect(find.text('Pantry Screen'), findsOneWidget);
    });
  });
}

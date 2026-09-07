import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/features/pantry/application/expiry_prediction_controller.dart';
import 'package:snacktrack/features/pantry/application/pantry_controller.dart';
import 'package:snacktrack/features/pantry/presentation/screens/item_scan_screen.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('ItemScanScreen', () {
    late FakePantryRepository pantryRepository;

    setUp(() {
      pantryRepository = FakePantryRepository();
    });

    Widget createTestWidget({
      String? initialName,
      String? initialCategory,
      double? initialQuantity,
      required GoRouter router,
    }) {
      return ProviderScope(
        overrides: [
          pantryControllerProvider.overrideWith(
            (ref) => PantryController(pantryRepository),
          ),
          expiryPredictionControllerProvider.overrideWith(
            (ref) => ExpiryPredictionController(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('shows validation snackbar error when saving with empty item name', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/item-scan',
            builder: (context, state) => const ItemScanScreen(initialName: ''),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(router: router));
      router.push('/item-scan');
      await tester.pumpAndSettle();

      expect(find.text('Save to Pantry'), findsOneWidget);
      await tester.tap(find.text('Save to Pantry'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter an item name'), findsOneWidget);
      expect(pantryRepository.items, isEmpty);
    });

    testWidgets('saves valid item to pantry repository on button tap', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/item-scan',
            builder: (context, state) => const ItemScanScreen(
              initialName: 'Brown Rice',
              initialCategory: 'Pantry',
              initialQuantity: 2.0,
            ),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(router: router));
      router.push('/item-scan');
      await tester.pumpAndSettle();

      expect(find.text('Brown Rice'), findsOneWidget);
      expect(find.text('Save to Pantry'), findsOneWidget);

      await tester.tap(find.text('Save to Pantry'));
      await tester.pumpAndSettle();

      expect(pantryRepository.items.length, equals(1));
      expect(pantryRepository.items.first.name, equals('Brown Rice'));
      expect(find.text('Home'), findsOneWidget);
    });
  });
}

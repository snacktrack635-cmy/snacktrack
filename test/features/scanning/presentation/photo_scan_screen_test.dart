import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/features/scanning/application/scan_controller.dart';
import 'package:snacktrack/features/scanning/presentation/screens/photo_scan_screen.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('PhotoScanScreen', () {
    late FakeBarcodeRepository barcodeRepo;
    late FakeSubscriptionRepository subRepo;
    late FakeGeminiService geminiService;

    setUp(() {
      barcodeRepo = FakeBarcodeRepository();
      subRepo = FakeSubscriptionRepository();
      geminiService = FakeGeminiService();
    });

    Widget createTestWidget({DateTime? forcedDate}) {
      final router = GoRouter(
        initialLocation: '/scan/photo',
        routes: [
          GoRoute(
            path: '/scan/photo',
            builder: (context, state) => const PhotoScanScreen(),
          ),
          GoRoute(
            path: '/pantry/item-scan',
            builder: (context, state) => const Scaffold(body: Text('Item Scan Target')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          scanControllerProvider.overrideWith(
            (ref) {
              final controller = ScanController(
                barcodeRepository: barcodeRepo,
                subscriptionRepository: subRepo,
                geminiService: geminiService,
              );
              if (forcedDate != null) {
                controller.state = controller.state.copyWith(ocrDetectedDate: forcedDate);
              }
              return controller;
            },
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('renders guide banner and manual date selection button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Point at the Expiry Date Label'), findsOneWidget);
      expect(find.text('Manual Expiry Selection'), findsOneWidget);
      expect(find.text('Date Detected:'), findsNothing);
    });

    testWidgets('displays detected date card when date is detected by OCR', (tester) async {
      final detected = DateTime(2026, 12, 25);
      await tester.pumpWidget(createTestWidget(forcedDate: detected));
      await tester.pumpAndSettle();

      expect(find.text('Date Detected:'), findsOneWidget);
      expect(find.text('2026-12-25'), findsOneWidget);
      expect(find.text('Use This Date'), findsOneWidget);

      await tester.tap(find.text('Use This Date'));
      await tester.pumpAndSettle();

      expect(find.text('Item Scan Target'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/widgets/expiry_badge.dart';

void main() {
  group('ExpiryBadge Widget', () {
    testWidgets('renders fresh status badge with expiry source', (tester) async {
      final futureDate = DateTime.now().add(const Duration(days: 14));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpiryBadge(
              expiryDate: futureDate,
              expirySource: 'Gemini AI',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
      expect(find.text('Expires in 14 days'), findsOneWidget);
      expect(find.text('(Gemini AI)'), findsOneWidget);
    });

    testWidgets('renders expiring soon status', (tester) async {
      final soonDate = DateTime.now().add(const Duration(days: 2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpiryBadge(expiryDate: soonDate),
          ),
        ),
      );

      expect(find.text('Expires in 2 days'), findsOneWidget);
    });

    testWidgets('renders expired status when date is in past', (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 3));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpiryBadge(expiryDate: pastDate),
          ),
        ),
      );

      expect(find.text('Expired (3d ago)'), findsOneWidget);
    });

    testWidgets('renders unknown badge when date is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExpiryBadge(expiryDate: null),
          ),
        ),
      );

      expect(find.text('No expiry date'), findsOneWidget);
    });
  });
}

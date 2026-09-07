import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/widgets/error_view.dart';

void main() {
  group('ErrorView Widget', () {
    testWidgets('renders error message and icon without retry button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorView(message: 'Something went wrong!'),
          ),
        ),
      );

      expect(find.text('Something went wrong!'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('renders Retry button and triggers onRetry callback when tapped', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'Failed to load data',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/widgets/loading_view.dart';

void main() {
  group('LoadingView Widget', () {
    testWidgets('renders circular progress indicator without message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingView(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders circular progress indicator with custom message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingView(message: 'Generating AI recipe...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Generating AI recipe...'), findsOneWidget);
    });
  });
}

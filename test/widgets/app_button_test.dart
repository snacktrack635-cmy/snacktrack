import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/widgets/app_button.dart';

void main() {
  group('AppButton Widget', () {
    testWidgets('renders label and triggers onPressed when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Save Item',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Save Item'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('Save Item'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('renders icon when specified', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Scan Food',
              icon: Icons.camera_alt,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.text('Scan Food'), findsOneWidget);
    });

    testWidgets('shows loading indicator and disables tap when isLoading is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Processing',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Processing'), findsNothing);

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('renders correctly across all button variants', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppButton(label: 'Primary', variant: AppButtonVariant.primary),
                AppButton(label: 'Secondary', variant: AppButtonVariant.secondary),
                AppButton(label: 'Outlined', variant: AppButtonVariant.outlined),
                AppButton(label: 'Text', variant: AppButtonVariant.text),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Outlined'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
    });
  });
}

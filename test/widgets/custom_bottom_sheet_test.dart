import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/widgets/custom_bottom_sheet.dart';

void main() {
  group('CustomBottomSheet', () {
    testWidgets('renders bottom sheet modal with title and content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CustomBottomSheet.show(
                    context: context,
                    title: 'Add Custom Item',
                    child: const Text('Modal Body Content'),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Open Sheet'), findsOneWidget);
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Add Custom Item'), findsOneWidget);
      expect(find.text('Modal Body Content'), findsOneWidget);
    });
  });
}

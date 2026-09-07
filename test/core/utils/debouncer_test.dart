import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('executes action after specified delay', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      int callCount = 0;

      debouncer.run(() {
        callCount++;
      });

      expect(callCount, equals(0));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(callCount, equals(1));
      debouncer.dispose();
    });

    test('coalesces multiple rapid calls into a single invocation', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 60));
      int callCount = 0;

      debouncer.run(() => callCount++);
      await Future.delayed(const Duration(milliseconds: 20));
      debouncer.run(() => callCount++);
      await Future.delayed(const Duration(milliseconds: 20));
      debouncer.run(() => callCount++);

      expect(callCount, equals(0));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(callCount, equals(1));
      debouncer.dispose();
    });

    test('dispose cancels any pending execution', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      int callCount = 0;

      debouncer.run(() {
        callCount++;
      });

      debouncer.dispose();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(callCount, equals(0));
    });
  });
}

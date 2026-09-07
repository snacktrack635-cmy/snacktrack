import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter', () {
    test('formatDate formats valid date with leading zeros', () {
      final date = DateTime(2026, 3, 5);
      expect(DateFormatter.formatDate(date), equals('2026-03-05'));
    });

    test('formatDate returns "No date" when null is passed', () {
      expect(DateFormatter.formatDate(null), equals('No date'));
    });

    test('parseDate parses valid ISO strings correctly', () {
      final parsed = DateFormatter.parseDate('2026-11-20');
      expect(parsed, isNotNull);
      expect(parsed!.year, equals(2026));
      expect(parsed.month, equals(11));
      expect(parsed.day, equals(20));
    });

    test('parseDate returns null for null, empty or invalid strings', () {
      expect(DateFormatter.parseDate(null), isNull);
      expect(DateFormatter.parseDate(''), isNull);
      expect(DateFormatter.parseDate('invalid-date-string'), isNull);
      expect(DateFormatter.parseDate('2026/99/99'), isNull);
    });

    test('daysUntilExpiry returns 999 when date is null', () {
      expect(DateFormatter.daysUntilExpiry(null), equals(999));
    });

    test('daysUntilExpiry computes correct difference from today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(DateFormatter.daysUntilExpiry(today), equals(0));

      final tomorrow = today.add(const Duration(days: 1));
      expect(DateFormatter.daysUntilExpiry(tomorrow), equals(1));

      final threeDaysLater = today.add(const Duration(days: 3));
      expect(DateFormatter.daysUntilExpiry(threeDaysLater), equals(3));

      final yesterday = today.subtract(const Duration(days: 1));
      expect(DateFormatter.daysUntilExpiry(yesterday), equals(-1));
    });

    test('getExpiryStatus correctly classifies dates', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(DateFormatter.getExpiryStatus(null), equals(ExpiryStatus.unknown));
      expect(DateFormatter.getExpiryStatus(today.subtract(const Duration(days: 2))), equals(ExpiryStatus.expired));
      expect(DateFormatter.getExpiryStatus(today), equals(ExpiryStatus.expiringSoon));
      expect(DateFormatter.getExpiryStatus(today.add(const Duration(days: 2))), equals(ExpiryStatus.expiringSoon));
      expect(DateFormatter.getExpiryStatus(today.add(const Duration(days: 3))), equals(ExpiryStatus.expiringSoon));
      expect(DateFormatter.getExpiryStatus(today.add(const Duration(days: 4))), equals(ExpiryStatus.fresh));
      expect(DateFormatter.getExpiryStatus(today.add(const Duration(days: 30))), equals(ExpiryStatus.fresh));
    });

    test('formatExpiryLabel formats human-readable labels properly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(DateFormatter.formatExpiryLabel(null), equals('No expiry date'));
      expect(DateFormatter.formatExpiryLabel(today.subtract(const Duration(days: 4))), equals('Expired (4d ago)'));
      expect(DateFormatter.formatExpiryLabel(today), equals('Expires today'));
      expect(DateFormatter.formatExpiryLabel(today.add(const Duration(days: 1))), equals('Expires tomorrow'));
      expect(DateFormatter.formatExpiryLabel(today.add(const Duration(days: 3))), equals('Expires in 3 days'));
      expect(DateFormatter.formatExpiryLabel(today.add(const Duration(days: 10))), equals('Expires in 10 days'));
    });
  });
}

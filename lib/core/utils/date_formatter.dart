enum ExpiryStatus {
  fresh,
  expiringSoon,
  expired,
  unknown,
}

class DateFormatter {
  DateFormatter._();

  static String formatDate(DateTime? date) {
    if (date == null) return 'No date';
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  static int daysUntilExpiry(DateTime? expiryDate) {
    if (expiryDate == null) return 999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return target.difference(today).inDays;
  }

  static ExpiryStatus getExpiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) return ExpiryStatus.unknown;
    final days = daysUntilExpiry(expiryDate);
    if (days < 0) return ExpiryStatus.expired;
    if (days <= 3) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.fresh;
  }

  static String formatExpiryLabel(DateTime? expiryDate) {
    if (expiryDate == null) return 'No expiry date';
    final days = daysUntilExpiry(expiryDate);
    if (days < 0) return 'Expired (${days.abs()}d ago)';
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    if (days <= 3) return 'Expires in $days days';
    return 'Expires in $days days';
  }
}

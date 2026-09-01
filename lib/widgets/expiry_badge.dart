import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/utils/date_formatter.dart';

class ExpiryBadge extends StatelessWidget {
  final DateTime? expiryDate;
  final String? expirySource;

  const ExpiryBadge({
    super.key,
    required this.expiryDate,
    this.expirySource,
  });

  @override
  Widget build(BuildContext context) {
    final status = DateFormatter.getExpiryStatus(expiryDate);
    final label = DateFormatter.formatExpiryLabel(expiryDate);

    Color badgeColor;
    Color textColor;

    switch (status) {
      case ExpiryStatus.fresh:
        badgeColor = AppColors.expiryFresh.withValues(alpha: 0.15);
        textColor = AppColors.expiryFresh;
        break;
      case ExpiryStatus.expiringSoon:
        badgeColor = AppColors.expiryWarning.withValues(alpha: 0.15);
        textColor = AppColors.expiryWarning;
        break;
      case ExpiryStatus.expired:
        badgeColor = AppColors.expiryCritical.withValues(alpha: 0.15);
        textColor = AppColors.expiryCritical;
        break;
      case ExpiryStatus.unknown:
        badgeColor = Colors.grey.withValues(alpha: 0.15);
        textColor = Colors.grey.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (expirySource != null) ...[
            const SizedBox(width: 4),
            Text(
              '($expirySource)',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/core/utils/date_formatter.dart';
import 'package:snacktrack/features/scanning/application/scan_controller.dart';
import 'package:snacktrack/widgets/app_button.dart';

class PhotoScanScreen extends ConsumerStatefulWidget {
  const PhotoScanScreen({super.key});

  @override
  ConsumerState<PhotoScanScreen> createState() => _PhotoScanScreenState();
}

class _PhotoScanScreenState extends ConsumerState<PhotoScanScreen> {
  final TextEditingController _manualOcrController = TextEditingController();

  @override
  void dispose() {
    _manualOcrController.dispose();
    super.dispose();
  }

  void _onConfirmDate(DateTime date) {
    context.push(
      '/pantry/item-scan',
      extra: {
        'expiryDate': date,
        'expirySource': 'label_ocr',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Expiry Date Label'),
      ),
      body: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Guide box
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Point at the Expiry Date Label',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'On-device ML Kit OCR will detect dates like "EXP: 12/2026", "BEST BEFORE 15/10/26", etc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            if (scanState.ocrDetectedDate != null) ...[
              Card(
                color: AppColors.expiryFresh.withValues(alpha: 0.1),
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    children: [
                      const Text(
                        'Date Detected:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormatter.formatDate(scanState.ocrDetectedDate),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Use This Date',
                        icon: Icons.check_circle_outline,
                        onPressed: () => _onConfirmDate(scanState.ocrDetectedDate!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            const Spacer(),

            // Fallback manual date picker / entry
            AppButton(
              label: 'Manual Expiry Selection',
              variant: AppButtonVariant.outlined,
              icon: Icons.calendar_today_rounded,
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  _onConfirmDate(picked);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/features/scanning/application/scan_controller.dart';
import 'package:snacktrack/widgets/app_button.dart';

class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isHandlingScan = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isHandlingScan) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _isHandlingScan = true;
    final result = await ref.read(scanControllerProvider.notifier).processBarcode(rawValue);

    if (!mounted) return;

    final scanState = ref.read(scanControllerProvider);
    if (scanState.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(scanState.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
      _isHandlingScan = false;
      return;
    }

    // Navigate to Item review / edit screen with detected details
    await context.push(
      '/pantry/item-scan',
      extra: {
        'name': result?.name ?? 'Scanned Item',
        'barcode': rawValue,
        'category': result?.category,
        'imageUrl': result?.imageUrl,
      },
    );

    _isHandlingScan = false;
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: () => _scannerController.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'Scan Expiry Date Label',
            onPressed: () => context.push('/scan/photo'),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
            tooltip: 'Scan Food Item with Gemini AI',
            onPressed: () => context.push('/scan/ai'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
          ),

          // Viewfinder Overlay
          Center(
            child: Container(
              width: 260,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2.5),
                borderRadius: AppSpacing.borderRadiusLg,
                color: Colors.black.withValues(alpha: 0.1),
              ),
            ),
          ),

          // Bottom Bar for Actions
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scanState.isProcessing)
                  Container(
                    padding: AppSpacing.paddingMd,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: AppSpacing.borderRadiusMd,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Looking up product info...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                AppButton(
                  label: 'Take Photo',
                  icon: Icons.auto_awesome,
                  width: double.infinity,
                  onPressed: () {
                    context.push('/scan/ai');
                  },
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Add Manually Without Barcode',
                  icon: Icons.edit_note_rounded,
                  variant: AppButtonVariant.secondary,
                  width: double.infinity,
                  onPressed: () {
                    context.push('/pantry/item-scan');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

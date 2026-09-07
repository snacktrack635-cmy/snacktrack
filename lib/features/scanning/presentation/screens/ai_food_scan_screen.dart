import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../widgets/app_button.dart';
import '../../application/scan_controller.dart';

class AiFoodScanScreen extends ConsumerStatefulWidget {
  const AiFoodScanScreen({super.key});

  @override
  ConsumerState<AiFoodScanScreen> createState() => _AiFoodScanScreenState();
}

class _AiFoodScanScreenState extends ConsumerState<AiFoodScanScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isAnalyzing = false;

  Future<void> _captureWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
        await _processImageWithGemini(File(photo.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        await _processImageWithGemini(File(image.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _processImageWithGemini(File file) async {
    setState(() {
      _isAnalyzing = true;
    });

    final scanNotifier = ref.read(scanControllerProvider.notifier);
    final result = await scanNotifier.processAiFoodScan(
      imageFile: file,
      imagePath: file.path,
    );

    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
    });

    final scanState = ref.read(scanControllerProvider);
    if (scanState.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(scanState.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (result != null) {
      if (result.rawResponse?['fallback'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI function not yet deployed on Supabase. Please review and confirm item details.'),
            backgroundColor: AppColors.secondaryDark,
            duration: Duration(seconds: 3),
          ),
        );
      }
      // Navigate to Review/Edit Screen so user can inspect and manually adjust expiry date
      await context.push(
        '/pantry/item-scan',
        extra: result.toItemScanExtra(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final isBusy = _isAnalyzing || scanState.isProcessing;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('AI Food Item Scanner'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Explanatory Banner
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology_alt_rounded, size: 36, color: AppColors.primary),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(
                          'Snap fresh produce, unpackaged groceries, or meals. Gemini identifies the item and estimates approximate shelf life.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Image Preview or Placeholder Box
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(
                  color: _selectedImage != null ? AppColors.primary : Colors.grey.shade300,
                  width: _selectedImage != null ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedImage != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                        if (isBusy)
                          Container(
                            color: Colors.black54,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Gemini AI is analyzing item & expiry...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_enhance_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No food photo selected yet',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Take a photo or pick from gallery below',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Camera Capture Button
            AppButton(
              label: isBusy ? 'Analyzing...' : 'Take Food Photo',
              icon: Icons.camera_alt_rounded,
              isLoading: isBusy,
              onPressed: isBusy ? null : _captureWithCamera,
            ),

            const SizedBox(height: AppSpacing.md),

            // Gallery Pick Button
            AppButton(
              label: 'Choose from Gallery',
              icon: Icons.photo_library_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: isBusy ? null : _pickFromGallery,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Helpful hints card
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: AppSpacing.borderRadiusMd,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: AppColors.secondary),
                      SizedBox(width: 6),
                      Text(
                        'Scanning Tips',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Center the food item under good lighting.\n'
                    '• Visual signs (e.g. peel color, firmness) improve expiry accuracy.\n'
                    '• You can manually edit the date and details on the next screen.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

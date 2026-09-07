import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/core/utils/date_formatter.dart';
import 'package:snacktrack/data/models/pantry_item.dart';
import 'package:snacktrack/features/pantry/application/expiry_prediction_controller.dart';
import 'package:snacktrack/features/pantry/application/pantry_controller.dart';
import 'package:snacktrack/widgets/app_button.dart';
import 'package:snacktrack/widgets/expiry_badge.dart';

class ItemScanScreen extends ConsumerStatefulWidget {
  final String? initialName;
  final String? initialBarcode;
  final String? initialCategory;
  final String? initialImageUrl;
  final DateTime? initialExpiryDate;
  final String initialExpirySource;
  final double? initialQuantity;
  final String? initialUnit;
  final String? freshnessNotes;
  final String? suggestedStorage;

  const ItemScanScreen({
    super.key,
    this.initialName,
    this.initialBarcode,
    this.initialCategory,
    this.initialImageUrl,
    this.initialExpiryDate,
    this.initialExpirySource = 'predicted',
    this.initialQuantity,
    this.initialUnit,
    this.freshnessNotes,
    this.suggestedStorage,
  });

  @override
  ConsumerState<ItemScanScreen> createState() => _ItemScanScreenState();
}

class _ItemScanScreenState extends ConsumerState<ItemScanScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  DateTime? _selectedExpiryDate;
  String _expirySource = 'predicted';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _categoryController = TextEditingController(text: widget.initialCategory ?? '');
    _quantityController = TextEditingController(
      text: widget.initialQuantity != null ? widget.initialQuantity!.toStringAsFixed(widget.initialQuantity! % 1 == 0 ? 0 : 1) : '1',
    );
    _unitController = TextEditingController(text: widget.initialUnit ?? 'pcs');
    _selectedExpiryDate = widget.initialExpiryDate;
    _expirySource = widget.initialExpirySource;

    if (_selectedExpiryDate == null && widget.initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(expiryPredictionControllerProvider.notifier)
            .predictFromCategory(widget.initialCategory);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
        _expirySource = 'manual';
      });
    }
  }

  void _saveItem() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name')),
      );
      return;
    }

    final predictionState = ref.read(expiryPredictionControllerProvider);
    final expiryDate = _selectedExpiryDate ?? predictionState.predictedExpiry;
    final expirySrc = _selectedExpiryDate != null ? _expirySource : predictionState.expirySource;

    final item = PantryItem(
      id: '',
      userId: '',
      name: _nameController.text.trim(),
      barcode: widget.initialBarcode,
      category: _categoryController.text.trim().isNotEmpty
          ? _categoryController.text.trim()
          : null,
      quantity: double.tryParse(_quantityController.text) ?? 1.0,
      unit: _unitController.text.trim().isNotEmpty
          ? _unitController.text.trim()
          : 'pcs',
      expiryDate: expiryDate,
      expirySource: expirySrc,
      imageUrl: widget.initialImageUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(pantryControllerProvider.notifier).addItem(item);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final predictionState = ref.watch(expiryPredictionControllerProvider);
    final effectiveExpiryDate = _selectedExpiryDate ?? predictionState.predictedExpiry;
    final effectiveSource = _selectedExpiryDate != null ? _expirySource : predictionState.expirySource;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Item'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Item Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name *',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Category
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              onChanged: (cat) {
                if (_selectedExpiryDate == null) {
                  ref
                      .read(expiryPredictionControllerProvider.notifier)
                      .predictFromCategory(cat);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Quantity & Unit
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit (e.g. pcs, L, kg)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Expiry Date Section
            Card(
              child: Padding(
                padding: AppSpacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (effectiveSource == 'ai_predicted') ...[
                              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                              const SizedBox(width: 6),
                            ],
                            const Text(
                              'Expiry Date',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        ExpiryBadge(
                          expiryDate: effectiveExpiryDate,
                          expirySource: effectiveSource == 'ai_predicted' ? 'Gemini AI' : effectiveSource,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      effectiveExpiryDate != null
                          ? 'Estimated: ${DateFormatter.formatDate(effectiveExpiryDate)}'
                          : 'No expiry date set',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),

                    // AI Freshness & Storage Insights
                    if (widget.freshnessNotes != null || widget.suggestedStorage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: AppSpacing.borderRadiusMd,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.freshnessNotes != null) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.visibility_outlined, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.freshnessNotes!,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (widget.suggestedStorage != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Recommended: Store in ${widget.suggestedStorage}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: effectiveSource == 'ai_predicted'
                          ? 'Edit Expiry Date Manually'
                          : 'Change Expiry Date',
                      variant: AppButtonVariant.outlined,
                      icon: Icons.calendar_month_rounded,
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Save to Pantry Button
            AppButton(
              label: 'Save to Pantry',
              icon: Icons.check_circle_outline_rounded,
              onPressed: _saveItem,
            ),
          ],
        ),
      ),
    );
  }
}

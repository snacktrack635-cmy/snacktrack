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

  const ItemScanScreen({
    super.key,
    this.initialName,
    this.initialBarcode,
    this.initialCategory,
    this.initialImageUrl,
    this.initialExpiryDate,
    this.initialExpirySource = 'predicted',
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
    _quantityController = TextEditingController(text: '1');
    _unitController = TextEditingController(text: 'pcs');
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
                        const Text(
                          'Expiry Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ExpiryBadge(
                          expiryDate: effectiveExpiryDate,
                          expirySource: effectiveSource,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      effectiveExpiryDate != null
                          ? 'Estimated: ${DateFormatter.formatDate(effectiveExpiryDate)}'
                          : 'No expiry date set',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Change Expiry Date',
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

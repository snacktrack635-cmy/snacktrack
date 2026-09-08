import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/core/utils/debouncer.dart';
import 'package:snacktrack/features/pantry/application/pantry_controller.dart';
import 'package:snacktrack/features/pantry/presentation/widgets/pantry_item_card.dart';
import 'package:snacktrack/features/recipes/application/recipe_generation_controller.dart';
import 'package:snacktrack/widgets/error_view.dart';
import 'package:snacktrack/widgets/loading_view.dart';

class PantryListScreen extends ConsumerStatefulWidget {
  const PantryListScreen({super.key});

  @override
  ConsumerState<PantryListScreen> createState() => _PantryListScreenState();
}

class _PantryListScreenState extends ConsumerState<PantryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 300));

  static const List<String> _categories = [
    'All',
    'Produce',
    'Dairy',
    'Meat',
    'Bakery',
    'Canned',
    'Pantry',
    'Snacks',
    'Beverages',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantryState = ref.watch(pantryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Pantry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: AppColors.secondary),
            tooltip: 'Expiring Soon Recipes',
            onPressed: () {
              context.push('/recipes/expiring-soon');
            },
          ),
          IconButton(
            icon: const Icon(Icons.star_rounded, color: AppColors.secondary),
            tooltip: 'Favorite Recipes',
            onPressed: () {
              context.push('/recipes/favorites');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search pantry items...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(pantryControllerProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                _debouncer.run(() {
                  ref.read(pantryControllerProvider.notifier).setSearchQuery(value);
                });
              },
            ),
          ),

          // Category Chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == pantryState.selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondaryLight,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      ref.read(pantryControllerProvider.notifier).setCategory(category);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Main Content
          Expanded(
            child: Builder(
              builder: (context) {
                if (pantryState.isLoading && pantryState.items.isEmpty) {
                  return const LoadingView(message: 'Loading pantry items...');
                }

                if (pantryState.errorMessage != null && pantryState.items.isEmpty) {
                  return ErrorView(
                    message: pantryState.errorMessage!,
                    onRetry: () => ref.read(pantryControllerProvider.notifier).loadItems(),
                  );
                }

                if (pantryState.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.kitchen_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Your pantry is empty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Scan items or add them manually to get started.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(pantryControllerProvider.notifier).loadItems(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: pantryState.items.length,
                    itemBuilder: (context, index) {
                      final item = pantryState.items[index];
                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: AppSpacing.borderRadiusMd,
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) {
                          ref.read(pantryControllerProvider.notifier).deleteItem(item.id);
                        },
                        child: PantryItemCard(
                          item: item,
                          onGenerateRecipe: () {
                            ref
                                .read(recipeGenerationControllerProvider.notifier)
                                .generateRecipeForItem(
                                  item.name,
                                  pantryItemId: item.id,
                                );
                            context.push('/recipes/detail', extra: item.name);
                          },
                          onDelete: () {
                            ref.read(pantryControllerProvider.notifier).deleteItem(item.id);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/scan/barcode');
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan Groceries'),
      ),
    );
  }
}

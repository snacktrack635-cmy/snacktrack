import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/data/models/shopping_list_item.dart';
import 'package:snacktrack/features/shopping_list/application/shopping_list_controller.dart';
import 'package:snacktrack/features/shopping_list/presentation/widgets/shopping_list_tile.dart';
import 'package:snacktrack/widgets/error_view.dart';
import 'package:snacktrack/widgets/loading_view.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final TextEditingController _addItemController = TextEditingController();

  @override
  void dispose() {
    _addItemController.dispose();
    super.dispose();
  }

  void _addNewItem() {
    final text = _addItemController.text.trim();
    if (text.isEmpty) return;

    ref.read(shoppingListControllerProvider.notifier).addItem(
          ShoppingListItem(
            id: '',
            userId: '',
            name: text,
            source: 'manual',
            createdAt: DateTime.now(),
          ),
        );
    _addItemController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shoppingListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Export CSV / Share',
            onPressed: state.items.isEmpty
                ? null
                : () => ref.read(shoppingListControllerProvider.notifier).exportList(),
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: 'Clear completed',
            onPressed: state.items.any((i) => i.isChecked)
                ? () => ref.read(shoppingListControllerProvider.notifier).clearCompleted()
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Add Input Box
          Padding(
            padding: AppSpacing.paddingMd,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addItemController,
                    decoration: const InputDecoration(
                      hintText: 'Add an item (e.g. Milk, Olive Oil)...',
                      prefixIcon: Icon(Icons.add_shopping_cart_rounded),
                    ),
                    onSubmitted: (_) => _addNewItem(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _addNewItem,
                ),
              ],
            ),
          ),

          // Shopping Items List
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.isLoading && state.items.isEmpty) {
                  return const LoadingView(message: 'Loading your shopping list...');
                }

                if (state.errorMessage != null && state.items.isEmpty) {
                  return ErrorView(
                    message: state.errorMessage!,
                    onRetry: () =>
                        ref.read(shoppingListControllerProvider.notifier).loadItems(),
                  );
                }

                if (state.items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: AppSpacing.paddingXl,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Your shopping list is empty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Type an item above or add missing ingredients from recipe suggestions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: state.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return ShoppingListTile(
                      item: item,
                      onCheckboxChanged: (val) {
                        ref
                            .read(shoppingListControllerProvider.notifier)
                            .toggleChecked(item.id, val ?? false);
                      },
                      onDelete: () {
                        ref
                            .read(shoppingListControllerProvider.notifier)
                            .deleteItem(item.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

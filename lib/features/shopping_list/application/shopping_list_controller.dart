import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/shopping_list_item.dart';
import '../../../data/repositories/shopping_list_repository.dart';
import '../../../providers/global_providers.dart';

class ShoppingListState {
  final List<ShoppingListItem> items;
  final bool isLoading;
  final String? errorMessage;
  final bool isExporting;

  const ShoppingListState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isExporting = false,
  });

  ShoppingListState copyWith({
    List<ShoppingListItem>? items,
    bool? isLoading,
    String? errorMessage,
    bool? isExporting,
  }) {
    return ShoppingListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isExporting: isExporting ?? this.isExporting,
    );
  }
}

class ShoppingListController extends StateNotifier<ShoppingListState> {
  final ShoppingListRepository _repository;

  ShoppingListController(this._repository) : super(const ShoppingListState()) {
    loadItems();
  }

  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _repository.getItems();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load shopping list: $e',
      );
    }
  }

  Future<void> addItem(ShoppingListItem item) async {
    try {
      final newItem = await _repository.addItem(item);
      state = state.copyWith(items: [newItem, ...state.items]);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to add shopping list item: $e');
    }
  }

  Future<void> toggleChecked(String itemId, bool isChecked) async {
    try {
      await _repository.toggleChecked(itemId, isChecked);
      final updated = state.items.map((i) {
        if (i.id == itemId) {
          return i.copyWith(isChecked: isChecked);
        }
        return i;
      }).toList();
      state = state.copyWith(items: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update item: $e');
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _repository.deleteItem(itemId);
      state = state.copyWith(
        items: state.items.where((i) => i.id != itemId).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete item: $e');
    }
  }

  Future<void> clearCompleted() async {
    try {
      await _repository.clearCompleted();
      state = state.copyWith(
        items: state.items.where((i) => !i.isChecked).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to clear completed items: $e');
    }
  }

  Future<void> exportList() async {
    if (state.items.isEmpty) return;
    state = state.copyWith(isExporting: true);
    try {
      await _repository.exportShoppingList(state.items);
      state = state.copyWith(isExporting: false);
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Failed to export shopping list: $e',
      );
    }
  }
}

final shoppingListControllerProvider =
    StateNotifierProvider<ShoppingListController, ShoppingListState>((ref) {
  final repo = ref.watch(shoppingListRepositoryProvider);
  return ShoppingListController(repo);
});

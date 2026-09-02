import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/pantry_item.dart';
import '../../../data/repositories/pantry_repository.dart';
import '../../../providers/global_providers.dart';

class PantryState {
  final List<PantryItem> items;
  final bool isLoading;
  final String? errorMessage;
  final String selectedCategory;
  final String searchQuery;

  const PantryState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory = 'All',
    this.searchQuery = '',
  });

  PantryState copyWith({
    List<PantryItem>? items,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return PantryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class PantryController extends StateNotifier<PantryState> {
  final PantryRepository _repository;

  PantryController(this._repository) : super(const PantryState()) {
    loadItems();
  }

  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _repository.getPantryItems(
        category: state.selectedCategory == 'All' ? null : state.selectedCategory,
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      );
      state = state.copyWith(items: items, isLoading: false);
    } catch (e, st) {
      debugPrint('❌ [PantryController.loadItems] Error: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load pantry items: $e',
      );
    }
  }

  Future<void> addItem(PantryItem item) async {
    try {
      final newItem = await _repository.addPantryItem(item);
      state = state.copyWith(items: [newItem, ...state.items]);
    } catch (e, st) {
      debugPrint('❌ [PantryController.addItem] Error: $e\n$st');
      state = state.copyWith(errorMessage: 'Failed to add item: $e');
    }
  }

  Future<void> updateItem(PantryItem item) async {
    try {
      final updated = await _repository.updatePantryItem(item);
      final index = state.items.indexWhere((element) => element.id == item.id);
      if (index != -1) {
        final updatedList = List<PantryItem>.from(state.items);
        updatedList[index] = updated;
        state = state.copyWith(items: updatedList);
      }
    } catch (e, st) {
      debugPrint('❌ [PantryController.updateItem] Error: $e\n$st');
      state = state.copyWith(errorMessage: 'Failed to update item: $e');
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _repository.deletePantryItem(itemId);
      state = state.copyWith(
        items: state.items.where((element) => element.id != itemId).toList(),
      );
    } catch (e, st) {
      debugPrint('❌ [PantryController.deleteItem] Error: $e\n$st');
      state = state.copyWith(errorMessage: 'Failed to delete item: $e');
    }
  }

  void setCategory(String category) {
    if (state.selectedCategory != category) {
      state = state.copyWith(selectedCategory: category);
      loadItems();
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadItems();
  }
}

final pantryControllerProvider =
    StateNotifierProvider<PantryController, PantryState>((ref) {
  final repository = ref.watch(pantryRepositoryProvider);
  return PantryController(repository);
});

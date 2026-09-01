import '../datasources/supabase_pantry_ds.dart';
import '../models/pantry_item.dart';

class PantryRepository {
  final SupabasePantryDataSource _dataSource;

  PantryRepository(this._dataSource);

  Future<List<PantryItem>> getPantryItems({
    int offset = 0,
    int limit = 50,
    String? category,
    String? searchQuery,
  }) async {
    return await _dataSource.getPantryItems(
      offset: offset,
      limit: limit,
      category: category,
      searchQuery: searchQuery,
    );
  }

  Future<List<PantryItem>> getExpiringSoonItems({int daysThreshold = 3}) async {
    return await _dataSource.getExpiringSoonItems(daysThreshold: daysThreshold);
  }

  Future<PantryItem> addPantryItem(PantryItem item) async {
    return await _dataSource.addPantryItem(item);
  }

  Future<PantryItem> updatePantryItem(PantryItem item) async {
    return await _dataSource.updatePantryItem(item);
  }

  Future<void> deletePantryItem(String itemId) async {
    await _dataSource.deletePantryItem(itemId);
  }
}

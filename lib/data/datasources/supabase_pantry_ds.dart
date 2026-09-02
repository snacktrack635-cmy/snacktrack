import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/supabase_client.dart';
import '../models/pantry_item.dart';

class SupabasePantryDataSource {
  final SupabaseClient _client;

  SupabasePantryDataSource(this._client);

  Future<List<PantryItem>> getPantryItems({
    int offset = 0,
    int limit = 50,
    String? category,
    String? searchQuery,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      var query = _client
          .from(AppConstants.pantryItemsTable)
          .select()
          .eq('user_id', userId);

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.eq('category', category);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }

      final response = await query
          .order('expiry_date', ascending: true, nullsFirst: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((json) => PantryItem.fromJson(json)).toList();
    } catch (e, st) {
      AppSupabaseClient.logError('getPantryItems', e, st);
      rethrow;
    }
  }

  Future<List<PantryItem>> getExpiringSoonItems({int daysThreshold = 3}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final targetDate = DateTime.now().add(Duration(days: daysThreshold));
      final targetDateStr =
          '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      final response = await _client
          .from(AppConstants.pantryItemsTable)
          .select()
          .eq('user_id', userId)
          .lte('expiry_date', targetDateStr)
          .order('expiry_date', ascending: true);

      return (response as List).map((json) => PantryItem.fromJson(json)).toList();
    } catch (e, st) {
      AppSupabaseClient.logError('getExpiringSoonItems', e, st);
      rethrow;
    }
  }

  Future<PantryItem> addPantryItem(PantryItem item) async {
    final userId = _client.auth.currentUser?.id;
    final itemData = item.toJson();
    if (userId != null) itemData['user_id'] = userId;
    itemData.remove('id'); // let Supabase generate UUID

    try {
      final response = await _client
          .from(AppConstants.pantryItemsTable)
          .insert(itemData)
          .select()
          .single();

      return PantryItem.fromJson(response);
    } catch (e, st) {
      AppSupabaseClient.logError('addPantryItem ("${item.name}")', e, st);
      rethrow;
    }
  }

  Future<PantryItem> updatePantryItem(PantryItem item) async {
    final itemData = item.toJson();
    itemData['updated_at'] = DateTime.now().toIso8601String();

    try {
      final response = await _client
          .from(AppConstants.pantryItemsTable)
          .update(itemData)
          .eq('id', item.id)
          .select()
          .single();

      return PantryItem.fromJson(response);
    } catch (e, st) {
      AppSupabaseClient.logError('updatePantryItem ("${item.id}")', e, st);
      rethrow;
    }
  }

  Future<void> deletePantryItem(String itemId) async {
    try {
      await _client
          .from(AppConstants.pantryItemsTable)
          .delete()
          .eq('id', itemId);
    } catch (e, st) {
      AppSupabaseClient.logError('deletePantryItem ("$itemId")', e, st);
      rethrow;
    }
  }
}

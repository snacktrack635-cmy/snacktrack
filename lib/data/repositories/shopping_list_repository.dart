import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/shopping_list_item.dart';

class ShoppingListRepository {
  final SupabaseClient _client;

  ShoppingListRepository(this._client);

  Future<List<ShoppingListItem>> getItems() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from(AppConstants.shoppingListItemsTable)
        .select()
        .eq('user_id', userId)
        .order('is_checked', ascending: true)
        .order('created_at', ascending: false);

    return (response as List).map((json) => ShoppingListItem.fromJson(json)).toList();
  }

  Future<ShoppingListItem> addItem(ShoppingListItem item) async {
    final userId = _client.auth.currentUser?.id;
    final data = item.toJson();
    if (userId != null) data['user_id'] = userId;
    data.remove('id');

    final response = await _client
        .from(AppConstants.shoppingListItemsTable)
        .insert(data)
        .select()
        .single();

    return ShoppingListItem.fromJson(response);
  }

  Future<ShoppingListItem> updateItem(ShoppingListItem item) async {
    final response = await _client
        .from(AppConstants.shoppingListItemsTable)
        .update(item.toJson())
        .eq('id', item.id)
        .select()
        .single();

    return ShoppingListItem.fromJson(response);
  }

  Future<void> toggleChecked(String itemId, bool isChecked) async {
    await _client
        .from(AppConstants.shoppingListItemsTable)
        .update({'is_checked': isChecked})
        .eq('id', itemId);
  }

  Future<void> deleteItem(String itemId) async {
    await _client
        .from(AppConstants.shoppingListItemsTable)
        .delete()
        .eq('id', itemId);
  }

  Future<void> clearCompleted() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from(AppConstants.shoppingListItemsTable)
        .delete()
        .eq('user_id', userId)
        .eq('is_checked', true);
  }

  /// Export shopping list as CSV format and share via native share sheet
  Future<void> exportShoppingList(List<ShoppingListItem> items) async {
    final List<List<dynamic>> rows = [
      ['Item Name', 'Quantity', 'Unit', 'Status', 'Source'],
      ...items.map((item) => [
            item.name,
            item.quantity,
            item.unit ?? '',
            item.isChecked ? 'Completed' : 'Pending',
            item.source,
          ]),
    ];

    final csvString = const ListToCsvConverter().convert(rows);
    await Share.share(
      csvString,
      subject: 'My Pantry Shopping List',
    );
  }
}

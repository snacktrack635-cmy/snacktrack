import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/constants/tier_limits.dart';
import 'package:snacktrack/core/errors/exceptions.dart';
import 'package:snacktrack/core/services/gemini_service.dart';
import 'package:snacktrack/data/datasources/edge_functions_ds.dart';
import 'package:snacktrack/data/models/ai_food_scan_result.dart';
import 'package:snacktrack/data/models/pantry_item.dart';
import 'package:snacktrack/data/models/recipe.dart';
import 'package:snacktrack/data/models/shopping_list_item.dart';
import 'package:snacktrack/data/models/subscription.dart';
import 'package:snacktrack/data/repositories/barcode_repository.dart';
import 'package:snacktrack/data/repositories/pantry_repository.dart';
import 'package:snacktrack/data/repositories/recipe_repository.dart';
import 'package:snacktrack/data/repositories/shopping_list_repository.dart';
import 'package:snacktrack/data/repositories/subscription_repository.dart';

// -------------------------------------------------------------
// Fake Pantry Repository
// -------------------------------------------------------------
class FakePantryRepository implements PantryRepository {
  List<PantryItem> items = [];
  List<PantryItem> expiringItems = [];
  bool throwOnGet = false;
  bool throwOnAdd = false;
  bool throwOnUpdate = false;
  bool throwOnDelete = false;
  bool throwOnExpiring = false;
  String errorMessage = 'Database connection failure';

  @override
  Future<List<PantryItem>> getPantryItems({
    int offset = 0,
    int limit = 50,
    String? category,
    String? searchQuery,
  }) async {
    if (throwOnGet) throw ServerException(errorMessage);
    var result = List<PantryItem>.from(items);
    if (category != null && category != 'All') {
      result = result.where((item) => item.category == category).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      result = result
          .where((item) =>
              item.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
    return result;
  }

  @override
  Future<List<PantryItem>> getExpiringSoonItems({int daysThreshold = 3}) async {
    if (throwOnExpiring) throw ServerException(errorMessage);
    return List<PantryItem>.from(expiringItems);
  }

  @override
  Future<PantryItem> addPantryItem(PantryItem item) async {
    if (throwOnAdd) throw ServerException(errorMessage);
    final newItem = item.copyWith(id: 'generated-id-${items.length + 1}');
    items.insert(0, newItem);
    return newItem;
  }

  @override
  Future<PantryItem> updatePantryItem(PantryItem item) async {
    if (throwOnUpdate) throw ServerException(errorMessage);
    final index = items.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      items[index] = item;
    }
    return item;
  }

  @override
  Future<void> deletePantryItem(String itemId) async {
    if (throwOnDelete) throw ServerException(errorMessage);
    items.removeWhere((element) => element.id == itemId);
  }
}

// -------------------------------------------------------------
// Fake Recipe Repository
// -------------------------------------------------------------
class FakeRecipeRepository implements RecipeRepository {
  Recipe? recipeToReturn;
  Recipe? expiringSoonRecipeToReturn;
  List<FavoriteRecipe> favorites = [];
  bool throwOnGenerate = false;
  bool throwQuotaOnGenerate = false;
  bool throwOnExpiring = false;
  bool throwQuotaOnExpiring = false;
  bool throwOnFavorites = false;
  bool throwOnAddFavorite = false;
  bool throwOnRemoveFavorite = false;
  String errorMessage = 'Edge function execution failed';

  @override
  Future<Recipe> generateRecipe({
    required String primaryIngredient,
    List<String> availablePantryItems = const [],
  }) async {
    if (throwQuotaOnGenerate) {
      throw const QuotaExceededException('Monthly recipe generation quota exceeded (429).');
    }
    if (throwOnGenerate) {
      throw ServerException(errorMessage);
    }
    return recipeToReturn ??
        Recipe(
          id: 'test-recipe-1',
          name: 'Delicious $primaryIngredient Delight',
          ingredients: [
            RecipeIngredient(name: primaryIngredient, quantity: '200g'),
            ...availablePantryItems
                .map((e) => RecipeIngredient(name: e, quantity: '1 unit')),
          ],
          instructions: [
            'Prepare all ingredients.',
            'Cook $primaryIngredient in a pan.',
            'Serve warm and enjoy.',
          ],
          primaryIngredient: primaryIngredient,
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<Recipe> generateExpiringSoonRecipe({
    required List<String> expiringItems,
  }) async {
    if (throwQuotaOnExpiring) {
      throw const QuotaExceededException('Monthly recipe generation quota exceeded (429).');
    }
    if (throwOnExpiring) {
      throw ServerException(errorMessage);
    }
    return expiringSoonRecipeToReturn ??
        Recipe(
          id: 'expiring-recipe-1',
          name: 'Zero Waste Stew',
          ingredients: expiringItems
              .map((e) => RecipeIngredient(name: e, quantity: '100g'))
              .toList(),
          instructions: ['Combine all expiring items in a pot and simmer.'],
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<List<FavoriteRecipe>> getFavorites() async {
    if (throwOnFavorites) throw ServerException(errorMessage);
    return List<FavoriteRecipe>.from(favorites);
  }

  @override
  Future<FavoriteRecipe> addFavorite(Recipe recipe) async {
    if (throwOnAddFavorite) throw ServerException(errorMessage);
    final fav = FavoriteRecipe(
      id: 'fav-${recipe.id}',
      userId: 'user-123',
      recipeId: recipe.id,
      recipeSnapshot: recipe,
      createdAt: DateTime.now(),
    );
    favorites.add(fav);
    return fav;
  }

  @override
  Future<void> removeFavorite(String recipeId) async {
    if (throwOnRemoveFavorite) throw ServerException(errorMessage);
    favorites.removeWhere((f) => f.recipeId == recipeId);
  }

  @override
  Future<bool> isFavorited(String recipeId) async {
    return favorites.any((f) => f.recipeId == recipeId);
  }
}

// -------------------------------------------------------------
// Fake Shopping List Repository
// -------------------------------------------------------------
class FakeShoppingListRepository implements ShoppingListRepository {
  List<ShoppingListItem> items = [];
  bool throwOnGet = false;
  bool throwOnAdd = false;
  bool throwOnUpdate = false;
  bool throwOnToggle = false;
  bool throwOnDelete = false;
  bool throwOnClear = false;
  bool throwOnExport = false;
  bool exportCalled = false;
  String errorMessage = 'Shopping list database error';

  @override
  Future<List<ShoppingListItem>> getItems() async {
    if (throwOnGet) throw ServerException(errorMessage);
    return List<ShoppingListItem>.from(items);
  }

  @override
  Future<ShoppingListItem> addItem(ShoppingListItem item) async {
    if (throwOnAdd) throw ServerException(errorMessage);
    final newItem = item.copyWith(id: 'item-${items.length + 1}');
    items.insert(0, newItem);
    return newItem;
  }

  @override
  Future<ShoppingListItem> updateItem(ShoppingListItem item) async {
    if (throwOnUpdate) throw ServerException(errorMessage);
    final index = items.indexWhere((i) => i.id == item.id);
    if (index != -1) items[index] = item;
    return item;
  }

  @override
  Future<void> toggleChecked(String itemId, bool isChecked) async {
    if (throwOnToggle) throw ServerException(errorMessage);
    final index = items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      items[index] = items[index].copyWith(isChecked: isChecked);
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    if (throwOnDelete) throw ServerException(errorMessage);
    items.removeWhere((i) => i.id == itemId);
  }

  @override
  Future<void> clearCompleted() async {
    if (throwOnClear) throw ServerException(errorMessage);
    items.removeWhere((i) => i.isChecked);
  }

  @override
  Future<void> exportShoppingList(List<ShoppingListItem> items) async {
    if (throwOnExport) throw Exception(errorMessage);
    exportCalled = true;
  }
}

// -------------------------------------------------------------
// Fake Subscription Repository
// -------------------------------------------------------------
class FakeSubscriptionRepository implements SubscriptionRepository {
  UserSubscription subscription = UserSubscription(
    id: 'sub-1',
    userId: 'user-1',
    tier: SubscriptionTier.free,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  UsageCounter usageCounter = UsageCounter(
    userId: 'user-1',
    periodStart: DateTime.now(),
    scansUsed: 0,
    recipesGenerated: 0,
  );
  bool canScanResult = true;
  bool canGenerateRecipeResult = true;
  bool throwOnGetSubscription = false;
  bool throwOnGetUsage = false;
  bool throwOnIncrement = false;
  int incrementScanUsageCalls = 0;
  String errorMessage = 'Subscription service unreachable';

  @override
  Future<UserSubscription> getSubscription() async {
    if (throwOnGetSubscription) throw ServerException(errorMessage);
    return subscription;
  }

  @override
  Future<UsageCounter> getUsageCounters() async {
    if (throwOnGetUsage) throw ServerException(errorMessage);
    return usageCounter;
  }

  @override
  Future<bool> canScan(SubscriptionTier tier, int currentScans) async {
    return canScanResult;
  }

  @override
  Future<bool> canGenerateRecipe(SubscriptionTier tier, int currentGenerations) async {
    return canGenerateRecipeResult;
  }

  @override
  Future<void> incrementScanUsage() async {
    if (throwOnIncrement) throw ServerException(errorMessage);
    incrementScanUsageCalls++;
    usageCounter = usageCounter.copyWith(scansUsed: usageCounter.scansUsed + 1);
  }
}

// -------------------------------------------------------------
// Fake Barcode Repository
// -------------------------------------------------------------
class FakeBarcodeRepository implements BarcodeRepository {
  BarcodeProductResult? productToReturn;
  bool throwOnError = false;
  String errorMessage = 'Failed barcode network call';

  @override
  Future<BarcodeProductResult?> lookupBarcode(String barcode) async {
    if (throwOnError) throw NetworkException(errorMessage);
    return productToReturn;
  }
}

// -------------------------------------------------------------
// Fake Gemini Service
// -------------------------------------------------------------
class FakeGeminiService implements GeminiService {
  AiFoodScanResult? scanResult;
  bool throwQuotaExceeded = false;
  bool throwScanException = false;
  bool throwGeneralException = false;
  String errorMessage = 'AI scan processing failed';

  @override
  Future<AiFoodScanResult> scanFoodItem({
    File? imageFile,
    String? imagePath,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    if (throwQuotaExceeded) {
      throw const QuotaExceededException('Monthly scan quota reached for FREE tier.');
    }
    if (throwScanException) {
      throw ScanException(errorMessage);
    }
    if (throwGeneralException) {
      throw ServerException(errorMessage);
    }

    return scanResult ??
        AiFoodScanResult(
          name: 'Fresh Red Apple',
          category: 'Produce',
          estimatedExpiryDate: DateTime.now().add(const Duration(days: 10)),
          daysUntilExpiry: 10,
          confidence: 0.95,
          freshnessNotes: 'Crisp and shiny skin.',
          suggestedStorage: 'refrigerator',
          estimatedQuantity: 2.0,
          estimatedUnit: 'pcs',
          imagePath: imagePath ?? imageFile?.path,
        );
  }

  @override
  Future<AiFoodScanResult> estimateExpiryForFoodName({
    required String foodName,
    String? category,
    String? storageLocation,
  }) async {
    if (throwScanException) throw ScanException(errorMessage);
    return AiFoodScanResult(
      name: foodName,
      category: category ?? 'Produce',
      estimatedExpiryDate: DateTime.now().add(const Duration(days: 7)),
      daysUntilExpiry: 7,
      confidence: 0.85,
    );
  }
}

// -------------------------------------------------------------
// Fake Edge Functions Data Source
// -------------------------------------------------------------
class FakeEdgeFunctionsDataSource implements EdgeFunctionsDataSource {
  int sessionCount = 1;
  bool throwOnSession = false;
  Recipe? recipeToReturn;
  bool throwQuota = false;
  bool throwServer = false;
  Map<String, dynamic>? aiScanData;

  @override
  Future<int> incrementSession() async {
    if (throwOnSession) throw const ServerException('Session increment failed');
    return sessionCount;
  }

  @override
  Future<Recipe> generateRecipe({
    required String primaryIngredient,
    List<String> availablePantryItems = const [],
  }) async {
    if (throwQuota) throw const QuotaExceededException('Quota exceeded');
    if (throwServer) throw const ServerException('Server error');
    return recipeToReturn ??
        Recipe(
          id: 'gen-1',
          name: 'Recipe with $primaryIngredient',
          ingredients: [RecipeIngredient(name: primaryIngredient)],
          instructions: ['Cook it.'],
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<Recipe> generateExpiringSoonRecipe({
    required List<String> expiringItems,
  }) async {
    if (throwQuota) throw const QuotaExceededException('Quota exceeded');
    if (throwServer) throw const ServerException('Server error');
    return recipeToReturn ??
        Recipe(
          id: 'exp-1',
          name: 'Expiring Stew',
          ingredients: expiringItems.map((e) => RecipeIngredient(name: e)).toList(),
          instructions: ['Boil together.'],
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<Map<String, dynamic>> scanFoodItemWithAi({
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    if (throwQuota) throw const QuotaExceededException('Quota exceeded');
    if (throwServer) throw const ServerException('Server error');
    return aiScanData ??
        {
          'name': 'Banana',
          'category': 'Produce',
          'days_until_expiry': 4,
          'confidence': 0.9,
          'freshness_notes': 'Yellow with brown spots',
          'suggested_storage': 'pantry',
          'estimated_quantity': 3.0,
          'estimated_unit': 'pcs',
        };
  }
}

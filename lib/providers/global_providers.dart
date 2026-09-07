import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/network/supabase_client.dart';
import '../core/services/gemini_service.dart';
import '../data/datasources/edge_functions_ds.dart';
import '../data/datasources/supabase_pantry_ds.dart';
import '../data/datasources/supabase_recipe_ds.dart';
import '../data/repositories/barcode_repository.dart';
import '../data/repositories/pantry_repository.dart';
import '../data/repositories/recipe_repository.dart';
import '../data/repositories/shopping_list_repository.dart';
import '../data/repositories/subscription_repository.dart';

// --- Supabase Client ---
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return AppSupabaseClient.client;
});

// --- Data Sources ---
final supabasePantryDataSourceProvider = Provider<SupabasePantryDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabasePantryDataSource(client);
});

final supabaseRecipeDataSourceProvider = Provider<SupabaseRecipeDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseRecipeDataSource(client);
});

final edgeFunctionsDataSourceProvider = Provider<EdgeFunctionsDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EdgeFunctionsDataSource(client);
});

// --- Repositories ---
final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  final dataSource = ref.watch(supabasePantryDataSourceProvider);
  return PantryRepository(dataSource);
});

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final recipeDs = ref.watch(supabaseRecipeDataSourceProvider);
  final edgeDs = ref.watch(edgeFunctionsDataSourceProvider);
  return RecipeRepository(
    recipeDataSource: recipeDs,
    edgeFunctionsDataSource: edgeDs,
  );
});

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ShoppingListRepository(client);
});

final barcodeRepositoryProvider = Provider<BarcodeRepository>((ref) {
  return BarcodeRepository();
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SubscriptionRepository(client);
});

// --- Services ---
final geminiServiceProvider = Provider<GeminiService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  const directApiKey = String.fromEnvironment('GEMINI_API_KEY');
  return GeminiService(
    supabaseClient: client,
    directApiKey: directApiKey.isNotEmpty ? directApiKey : null,
  );
});


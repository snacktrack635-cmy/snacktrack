export 'app_colors.dart';
export 'app_spacing.dart';
export 'tier_limits.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'SnackTrack';
  static const String appTagline = 'Smart Pantry & Recipe Tracker';

  // Supabase Table Names
  static const String profilesTable = 'profiles';
  static const String subscriptionsTable = 'subscriptions';
  static const String usageCountersTable = 'usage_counters';
  static const String pantryItemsTable = 'pantry_items';
  static const String recipesTable = 'recipes';
  static const String favoriteRecipesTable = 'favorite_recipes';
  static const String shoppingListItemsTable = 'shopping_list_items';

  // Supabase Edge Function Names
  static const String generateRecipeFunction = 'generate-recipe';
  static const String scanFoodItemFunction = 'scan-food-item';
  static const String stripeWebhookFunction = 'stripe-webhook';
  static const String incrementSessionFunction = 'increment-session';

  // Gemini Model & Configuration
  static const String geminiDefaultModel = 'gemini-3.6-flash';
  static const String geminiApiKeyEnv = 'GEMINI_API_KEY';

  // Expiry heuristic threshold (days)
  static const int expiringSoonDaysThreshold = 3;
}

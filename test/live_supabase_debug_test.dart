import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snacktrack/data/datasources/supabase_recipe_ds.dart';

import 'package:snacktrack/data/datasources/edge_functions_ds.dart';

void main() {
  test(
    'live Supabase favorite_recipes probe',
    () async {
      const supabaseUrl = 'https://tmckkcgymgdunakhdywj.supabase.co';
      const supabaseAnonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtY2trY2d5bWdkdW5ha2hkeXdqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNTA0NjUsImV4cCI6MjEwMzgyNjQ2NX0.-9KchXA-vhqMMF1dtUCuOW-ajb46-zbj6IL90RqBwZU';

      final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

      await client.auth.signInAnonymously();
      final user = client.auth.currentUser;
      debugPrint('User: ${user?.id}, role: ${user?.role}');

      // Ensure profile exists
      try {
        await client.from('profiles').upsert({'id': user!.id}).select().maybeSingle();
        debugPrint('Profile ensured for ${user.id}');
      } catch (e) {
        debugPrint('Profile error: $e');
      }

      final ds = SupabaseRecipeDataSource(client);

      // Check current favorites
      try {
        final existing = await ds.getFavorites();
        debugPrint('Current favorites count for user: ${existing.length}');
        for (final f in existing) {
          debugPrint('Existing favorite: id=${f.id}, recipeId=${f.recipeId}, name=${f.recipeSnapshot.name}');
        }
      } catch (e) {
        debugPrint('getFavorites error: $e');
      }

      // Check all favorite_recipes in DB
      try {
        final allFavs = await client.from('favorite_recipes').select('id, user_id, recipe_id').limit(10);
        debugPrint('Total sample favorites in DB: $allFavs');
      } catch (e) {
        debugPrint('Error querying favorite_recipes table directly: $e');
      }

      // Try generating a real recipe using EdgeFunctionsDataSource
      final edgeDs = EdgeFunctionsDataSource(client);
      try {
        debugPrint('Generating recipe for Apple...');
        final genRecipe = await edgeDs.generateRecipe(
          primaryIngredient: 'Apple',
        );
        debugPrint(
          'Generated recipe: id="${genRecipe.id}", name="${genRecipe.name}"',
        );
        debugPrint('Recipe JSON: ${genRecipe.toJson()}');

        // Now try to favorite it!
        final fav = await ds.addFavorite(
          recipeId: genRecipe.id,
          recipe: genRecipe,
        );
        debugPrint('Successfully favorited generated recipe: ${fav.toJson()}');
      } catch (e) {
        debugPrint('Error during generate & favorite: $e');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

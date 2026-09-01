class RecipeIngredient {
  final String name;
  final String? quantity;

  const RecipeIngredient({
    required this.name,
    this.quantity,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String? ?? '',
      quantity: json['quantity']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (quantity != null) 'quantity': quantity,
    };
  }
}

class Recipe {
  final String id;
  final String name;
  final String? normalizedName;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final String? primaryIngredient;
  final String source;
  final int generationCount;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.name,
    this.normalizedName,
    required this.ingredients,
    required this.instructions,
    this.primaryIngredient,
    this.source = 'gemini',
    this.generationCount = 1,
    required this.createdAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    var rawIngredients = json['ingredients'];
    List<RecipeIngredient> parsedIngredients = [];
    if (rawIngredients is List) {
      parsedIngredients = rawIngredients
          .map((item) {
            if (item is Map<String, dynamic>) {
              return RecipeIngredient.fromJson(item);
            } else if (item is String) {
              return RecipeIngredient(name: item);
            }
            return const RecipeIngredient(name: '');
          })
          .toList();
    }

    var rawInstructions = json['instructions'];
    List<String> parsedInstructions = [];
    if (rawInstructions is List) {
      parsedInstructions = rawInstructions.map((e) => e.toString()).toList();
    }

    return Recipe(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Recipe',
      normalizedName: json['normalized_name'] as String?,
      ingredients: parsedIngredients,
      instructions: parsedInstructions,
      primaryIngredient: json['primary_ingredient'] as String?,
      source: json['source'] as String? ?? 'gemini',
      generationCount: (json['generation_count'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions,
      'primary_ingredient': primaryIngredient,
      'source': source,
      'generation_count': generationCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class FavoriteRecipe {
  final String id;
  final String userId;
  final String recipeId;
  final Recipe recipeSnapshot;
  final DateTime createdAt;

  const FavoriteRecipe({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.recipeSnapshot,
    required this.createdAt,
  });

  factory FavoriteRecipe.fromJson(Map<String, dynamic> json) {
    return FavoriteRecipe(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      recipeId: json['recipe_id'] as String,
      recipeSnapshot: Recipe.fromJson(
        json['recipe_snapshot'] as Map<String, dynamic>,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'recipe_id': recipeId,
      'recipe_snapshot': recipeSnapshot.toJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

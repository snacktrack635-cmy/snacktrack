import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/recipe.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/pantry/presentation/screens/item_scan_screen.dart';
import '../../features/pantry/presentation/screens/pantry_list_screen.dart';
import '../../features/recipes/presentation/screens/expiring_soon_recipes_screen.dart';
import '../../features/recipes/presentation/screens/recipe_detail_screen.dart';
import '../../features/recipes/presentation/screens/recipe_list_screen.dart';
import '../../features/scanning/presentation/screens/barcode_scan_screen.dart';
import '../../features/scanning/presentation/screens/photo_scan_screen.dart';
import '../../features/shopping_list/presentation/screens/shopping_list_screen.dart';
import '../../features/subscription/presentation/screens/paywall_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/pantry',
  routes: [
    // Onboarding
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Main App Shell with Bottom Navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return ScaffoldWithNavBar(child: child);
      },
      routes: [
        GoRoute(
          path: '/pantry',
          builder: (context, state) => const PantryListScreen(),
        ),
        GoRoute(
          path: '/recipes',
          builder: (context, state) => const RecipeListScreen(),
        ),
        GoRoute(
          path: '/shopping-list',
          builder: (context, state) => const ShoppingListScreen(),
        ),
      ],
    ),

    // Scanning Screens
    GoRoute(
      path: '/scan/barcode',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BarcodeScanScreen(),
    ),
    GoRoute(
      path: '/scan/photo',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PhotoScanScreen(),
    ),

    // Item Review / Edit Screen
    GoRoute(
      path: '/pantry/item-scan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ItemScanScreen(
          initialName: extra?['name'] as String?,
          initialBarcode: extra?['barcode'] as String?,
          initialCategory: extra?['category'] as String?,
          initialImageUrl: extra?['imageUrl'] as String?,
          initialExpiryDate: extra?['expiryDate'] as DateTime?,
          initialExpirySource: extra?['expirySource'] as String? ?? 'predicted',
        );
      },
    ),

    // Recipe Screens
    GoRoute(
      path: '/recipes/detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        Recipe? recipe;
        if (state.extra is Recipe) {
          recipe = state.extra as Recipe;
        }
        return RecipeDetailScreen(initialRecipe: recipe);
      },
    ),
    GoRoute(
      path: '/recipes/expiring-soon',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExpiringSoonRecipesScreen(),
    ),
    GoRoute(
      path: '/recipes/favorites',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RecipeListScreen(),
    ),

    // Subscription Paywall
    GoRoute(
      path: '/subscription/paywall',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PaywallScreen(),
    ),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavBar({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/pantry')) return 0;
    if (location.startsWith('/recipes')) return 1;
    if (location.startsWith('/shopping-list')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/pantry');
        break;
      case 1:
        context.go('/recipes');
        break;
      case 2:
        context.go('/shopping-list');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen_outlined),
            activeIcon: Icon(Icons.kitchen_rounded),
            label: 'Pantry',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book_rounded),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart_rounded),
            label: 'Shopping',
          ),
        ],
      ),
    );
  }
}

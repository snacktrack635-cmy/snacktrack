import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/errors/exceptions.dart';
import 'package:snacktrack/data/datasources/supabase_pantry_ds.dart';
import 'package:snacktrack/data/models/pantry_item.dart';
import 'package:snacktrack/data/repositories/pantry_repository.dart';

class StubPantryDataSource implements SupabasePantryDataSource {
  List<PantryItem> items = [];
  List<PantryItem> expiringItems = [];
  bool throwError = false;

  @override
  Future<List<PantryItem>> getPantryItems({
    int offset = 0,
    int limit = 50,
    String? category,
    String? searchQuery,
  }) async {
    if (throwError) throw const ServerException('Database query failed');
    return items;
  }

  @override
  Future<List<PantryItem>> getExpiringSoonItems({int daysThreshold = 3}) async {
    if (throwError) throw const ServerException('Failed to query expiring items');
    return expiringItems;
  }

  @override
  Future<PantryItem> addPantryItem(PantryItem item) async {
    if (throwError) throw const ServerException('Failed to add pantry item');
    items.add(item);
    return item;
  }

  @override
  Future<PantryItem> updatePantryItem(PantryItem item) async {
    if (throwError) throw const ServerException('Failed to update pantry item');
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx != -1) items[idx] = item;
    return item;
  }

  @override
  Future<void> deletePantryItem(String itemId) async {
    if (throwError) throw const ServerException('Failed to delete pantry item');
    items.removeWhere((i) => i.id == itemId);
  }
}

void main() {
  group('PantryRepository', () {
    late StubPantryDataSource dataSource;
    late PantryRepository repository;

    setUp(() {
      dataSource = StubPantryDataSource();
      repository = PantryRepository(dataSource);
    });

    test('getPantryItems returns list on success', () async {
      final item = PantryItem(
        id: 'p-1',
        userId: 'u-1',
        name: 'Apples',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      dataSource.items = [item];

      final result = await repository.getPantryItems();
      expect(result.length, equals(1));
      expect(result.first.name, equals('Apples'));
    });

    test('getPantryItems rethrows exception on failure', () async {
      dataSource.throwError = true;
      expect(() => repository.getPantryItems(), throwsA(isA<ServerException>()));
    });

    test('getExpiringSoonItems returns expiring items', () async {
      final expiring = PantryItem(
        id: 'p-2',
        userId: 'u-1',
        name: 'Milk',
        expiryDate: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      dataSource.expiringItems = [expiring];

      final result = await repository.getExpiringSoonItems();
      expect(result.length, equals(1));
      expect(result.first.name, equals('Milk'));
    });

    test('addPantryItem successfully saves item', () async {
      final item = PantryItem(
        id: 'p-3',
        userId: 'u-1',
        name: 'Cheese',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final added = await repository.addPantryItem(item);
      expect(added.name, equals('Cheese'));
      expect(dataSource.items.length, equals(1));
    });

    test('updatePantryItem updates item in data source', () async {
      final item = PantryItem(
        id: 'p-4',
        userId: 'u-1',
        name: 'Bread',
        quantity: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      dataSource.items = [item];

      final updated = await repository.updatePantryItem(item.copyWith(quantity: 2.0));
      expect(updated.quantity, equals(2.0));
      expect(dataSource.items.first.quantity, equals(2.0));
    });

    test('deletePantryItem removes item from data source', () async {
      final item = PantryItem(
        id: 'p-5',
        userId: 'u-1',
        name: 'Yogurt',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      dataSource.items = [item];

      await repository.deletePantryItem('p-5');
      expect(dataSource.items, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/pantry_item.dart';
import 'package:snacktrack/features/pantry/application/pantry_controller.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('PantryController', () {
    late FakePantryRepository repository;
    late PantryController controller;

    setUp(() {
      repository = FakePantryRepository();
      controller = PantryController(repository);
    });

    test('initial state loads items from repository', () async {
      final item = PantryItem(
        id: 'p-1',
        userId: 'u-1',
        name: 'Eggs',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      repository.items = [item];

      await controller.loadItems();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.items.length, equals(1));
      expect(controller.state.items.first.name, equals('Eggs'));
      expect(controller.state.errorMessage, isNull);
    });

    test('loadItems sets errorMessage when repository fails', () async {
      repository.throwOnGet = true;
      repository.errorMessage = 'Network timeout';

      await controller.loadItems();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.items, isEmpty);
      expect(controller.state.errorMessage, contains('Failed to load pantry items'));
      expect(controller.state.errorMessage, contains('Network timeout'));
    });

    test('addItem prepends new item to items list', () async {
      final item = PantryItem(
        id: 'p-new',
        userId: 'u-1',
        name: 'Avocado',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await controller.addItem(item);

      expect(controller.state.items.length, equals(1));
      expect(controller.state.items.first.name, equals('Avocado'));
      expect(controller.state.errorMessage, isNull);
    });

    test('addItem sets errorMessage when repository throws error', () async {
      repository.throwOnAdd = true;
      repository.errorMessage = 'Disk quota full';

      final item = PantryItem(
        id: 'p-err',
        userId: 'u-1',
        name: 'Cheese',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await controller.addItem(item);

      expect(controller.state.items, isEmpty);
      expect(controller.state.errorMessage, contains('Failed to add item'));
      expect(controller.state.errorMessage, contains('Disk quota full'));
    });

    test('updateItem updates item in state.items list', () async {
      final original = PantryItem(
        id: 'p-1',
        userId: 'u-1',
        name: 'Milk',
        quantity: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      repository.items = [original];
      await controller.loadItems();

      final updated = original.copyWith(quantity: 2.0);
      await controller.updateItem(updated);

      expect(controller.state.items.first.quantity, equals(2.0));
      expect(controller.state.errorMessage, isNull);
    });

    test('updateItem sets errorMessage when repository fails', () async {
      final original = PantryItem(
        id: 'p-1',
        userId: 'u-1',
        name: 'Milk',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      repository.items = [original];
      await controller.loadItems();

      repository.throwOnUpdate = true;
      repository.errorMessage = 'Conflict in row update';

      await controller.updateItem(original.copyWith(name: 'Almond Milk'));

      expect(controller.state.errorMessage, contains('Failed to update item'));
      expect(controller.state.errorMessage, contains('Conflict in row update'));
    });

    test('deleteItem removes item from state.items', () async {
      final item1 = PantryItem(
        id: 'p-1',
        userId: 'u-1',
        name: 'Milk',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final item2 = PantryItem(
        id: 'p-2',
        userId: 'u-1',
        name: 'Bread',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      repository.items = [item1, item2];
      await controller.loadItems();

      await controller.deleteItem('p-1');

      expect(controller.state.items.length, equals(1));
      expect(controller.state.items.first.id, equals('p-2'));
      expect(controller.state.errorMessage, isNull);
    });

    test('deleteItem sets errorMessage when repository fails', () async {
      repository.throwOnDelete = true;
      repository.errorMessage = 'Cannot delete locked item';

      await controller.deleteItem('p-1');

      expect(controller.state.errorMessage, contains('Failed to delete item'));
    });

    test('setCategory updates category and reloads items', () async {
      repository.items = [
        PantryItem(
          id: 'p-1',
          userId: 'u-1',
          name: 'Banana',
          category: 'Produce',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PantryItem(
          id: 'p-2',
          userId: 'u-1',
          name: 'Cheese',
          category: 'Dairy',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      controller.setCategory('Produce');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(controller.state.selectedCategory, equals('Produce'));
      expect(controller.state.items.length, equals(1));
      expect(controller.state.items.first.name, equals('Banana'));
    });

    test('setSearchQuery updates query and reloads items', () async {
      repository.items = [
        PantryItem(
          id: 'p-1',
          userId: 'u-1',
          name: 'Greek Yogurt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PantryItem(
          id: 'p-2',
          userId: 'u-1',
          name: 'Cheddar Cheese',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      controller.setSearchQuery('Yogurt');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(controller.state.searchQuery, equals('Yogurt'));
      expect(controller.state.items.length, equals(1));
      expect(controller.state.items.first.name, equals('Greek Yogurt'));
    });
  });
}

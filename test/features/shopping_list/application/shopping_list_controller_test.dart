import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/shopping_list_item.dart';
import 'package:snacktrack/features/shopping_list/application/shopping_list_controller.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('ShoppingListController', () {
    late FakeShoppingListRepository repository;
    late ShoppingListController controller;

    setUp(() {
      repository = FakeShoppingListRepository();
      controller = ShoppingListController(repository);
    });

    test('initial state loads items from repository', () async {
      final item = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Milk',
        createdAt: DateTime.now(),
      );
      repository.items = [item];

      await controller.loadItems();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.items.length, equals(1));
      expect(controller.state.errorMessage, isNull);
    });

    test('loadItems sets errorMessage on repository error', () async {
      repository.throwOnGet = true;
      repository.errorMessage = 'Network timeout';

      await controller.loadItems();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.items, isEmpty);
      expect(controller.state.errorMessage, contains('Failed to load shopping list'));
    });

    test('addItem prepends item to list', () async {
      final item = ShoppingListItem(
        id: 'i-2',
        userId: 'u-1',
        name: 'Eggs',
        createdAt: DateTime.now(),
      );

      await controller.addItem(item);

      expect(controller.state.items.length, equals(1));
      expect(controller.state.items.first.name, equals('Eggs'));
      expect(controller.state.errorMessage, isNull);
    });

    test('addItem sets errorMessage when repository fails', () async {
      repository.throwOnAdd = true;
      repository.errorMessage = 'Insert conflict';

      final item = ShoppingListItem(
        id: 'i-fail',
        userId: 'u-1',
        name: 'Bread',
        createdAt: DateTime.now(),
      );

      await controller.addItem(item);

      expect(controller.state.items, isEmpty);
      expect(controller.state.errorMessage, contains('Failed to add shopping list item'));
    });

    test('toggleChecked updates isChecked in state', () async {
      final item = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Apples',
        isChecked: false,
        createdAt: DateTime.now(),
      );
      repository.items = [item];
      await controller.loadItems();

      await controller.toggleChecked('i-1', true);

      expect(controller.state.items.first.isChecked, isTrue);
      expect(controller.state.errorMessage, isNull);
    });

    test('toggleChecked sets errorMessage when repository fails', () async {
      final item = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Apples',
        createdAt: DateTime.now(),
      );
      repository.items = [item];
      await controller.loadItems();

      repository.throwOnToggle = true;
      repository.errorMessage = 'Failed to toggle';

      await controller.toggleChecked('i-1', true);

      expect(controller.state.errorMessage, contains('Failed to update item'));
    });

    test('deleteItem removes item from state', () async {
      final item = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Orange',
        createdAt: DateTime.now(),
      );
      repository.items = [item];
      await controller.loadItems();

      await controller.deleteItem('i-1');

      expect(controller.state.items, isEmpty);
      expect(controller.state.errorMessage, isNull);
    });

    test('deleteItem sets errorMessage when repository fails', () async {
      repository.throwOnDelete = true;
      repository.errorMessage = 'Delete error';

      await controller.deleteItem('i-1');

      expect(controller.state.errorMessage, contains('Failed to delete item'));
    });

    test('clearCompleted removes only checked items', () async {
      final item1 = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Done Item',
        isChecked: true,
        createdAt: DateTime.now(),
      );
      final item2 = ShoppingListItem(
        id: 'i-2',
        userId: 'u-1',
        name: 'Pending Item',
        isChecked: false,
        createdAt: DateTime.now(),
      );
      repository.items = [item1, item2];
      await controller.loadItems();

      await controller.clearCompleted();

      expect(controller.state.items.length, equals(1));
      expect(controller.state.items.first.name, equals('Pending Item'));
      expect(controller.state.errorMessage, isNull);
    });

    test('clearCompleted sets errorMessage when repository fails', () async {
      repository.throwOnClear = true;
      repository.errorMessage = 'Clear failed';

      await controller.clearCompleted();

      expect(controller.state.errorMessage, contains('Failed to clear completed items'));
    });

    test('exportList does nothing when item list is empty', () async {
      await controller.exportList();
      expect(repository.exportCalled, isFalse);
      expect(controller.state.isExporting, isFalse);
    });

    test('exportList invokes repository export when items present', () async {
      final item = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Tea',
        createdAt: DateTime.now(),
      );
      repository.items = [item];
      await controller.loadItems();

      await controller.exportList();

      expect(repository.exportCalled, isTrue);
      expect(controller.state.isExporting, isFalse);
      expect(controller.state.errorMessage, isNull);
    });

    test('exportList sets errorMessage when sharing fails', () async {
      final item = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Coffee',
        createdAt: DateTime.now(),
      );
      repository.items = [item];
      await controller.loadItems();

      repository.throwOnExport = true;
      repository.errorMessage = 'Share sheet unavailable';

      await controller.exportList();

      expect(controller.state.isExporting, isFalse);
      expect(controller.state.errorMessage, contains('Failed to export shopping list'));
    });
  });
}

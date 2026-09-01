import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/shopping_list_item.dart';

class ShoppingListTile extends StatelessWidget {
  final ShoppingListItem item;
  final ValueChanged<bool?>? onCheckboxChanged;
  final VoidCallback? onDelete;

  const ShoppingListTile({
    super.key,
    required this.item,
    this.onCheckboxChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: item.isChecked,
        activeColor: AppColors.primary,
        onChanged: onCheckboxChanged,
      ),
      title: Text(
        item.name,
        style: TextStyle(
          fontSize: 16,
          decoration: item.isChecked ? TextDecoration.lineThrough : null,
          color: item.isChecked ? AppColors.textSecondaryLight : AppColors.textPrimaryLight,
        ),
      ),
      subtitle: item.source != 'manual'
          ? Text(
              'Added from ${item.source}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
        onPressed: onDelete,
      ),
    );
  }
}

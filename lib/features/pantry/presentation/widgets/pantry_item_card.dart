import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../data/models/pantry_item.dart';
import '../../../../widgets/expiry_badge.dart';

class PantryItemCard extends StatelessWidget {
  final PantryItem item;
  final VoidCallback? onGenerateRecipe;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const PantryItemCard({
    super.key,
    required this.item,
    this.onGenerateRecipe,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              // Product Image or Icon
              ClipRRect(
                borderRadius: AppSpacing.borderRadiusSm,
                child: Container(
                  width: 56,
                  height: 56,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Icon(
                            Icons.kitchen_rounded,
                            color: AppColors.primary,
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.kitchen_rounded,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.kitchen_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.quantity > item.quantity.toInt() ? item.quantity.toString() : item.quantity.toInt().toString()} ${item.unit ?? 'pcs'}${item.category != null ? ' • ${item.category}' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ExpiryBadge(
                      expiryDate: item.expiryDate,
                      expirySource: item.expirySource,
                    ),
                  ],
                ),
              ),
              // Recipe Action Button
              IconButton(
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.secondary,
                ),
                tooltip: 'Generate Recipe',
                onPressed: onGenerateRecipe,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

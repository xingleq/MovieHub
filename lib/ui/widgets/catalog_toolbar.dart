import 'package:flutter/material.dart';

import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import 'block_asset.dart';

/// Search + sort + poster-density controls above a catalog grid,
/// styled per the design spec with rounded surfaces and candy accents.
class CatalogToolbar extends StatelessWidget {
  const CatalogToolbar({
    super.key,
    required this.searchController,
    required this.sortKey,
    required this.onSortChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final SortKey sortKey;
  final ValueChanged<SortKey> onSortChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: '搜索番剧、电影、演员',
                isDense: true,
                prefixIcon: const Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: BlockIcon(AppAssets.search, size: 28),
                ),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: onClearSearch,
                        icon: const BlockIcon(AppAssets.close, size: 24),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        PopupMenuButton<SortKey>(
          tooltip: '排序',
          initialValue: sortKey,
          onSelected: onSortChanged,
          itemBuilder: (context) => [
            for (final key in SortKey.values)
              PopupMenuItem(value: key, child: Text(key.label)),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: tokens.brickYellow,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              border: Border.all(color: tokens.cardBorder, width: 2),
              boxShadow: [
                BoxShadow(
                  color: tokens.hardShadow,
                  blurRadius: 0,
                  offset: const Offset(3, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlockIcon.fromMaterial(
                  Icons.sort,
                  size: 24,
                  color: AppTokens.onLightBrick,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  sortKey.label,
                  style: const TextStyle(
                    color: AppTokens.onLightBrick,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppTokens.onLightBrick,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

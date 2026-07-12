import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';

/// Search + sort + poster-density controls above a catalog grid.
class CatalogToolbar extends StatelessWidget {
  const CatalogToolbar({
    super.key,
    required this.searchController,
    required this.sortKey,
    required this.posterSize,
    required this.onSortChanged,
    required this.onPosterSizeChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final SortKey sortKey;
  final PosterSize posterSize;
  final ValueChanged<SortKey> onSortChanged;
  final ValueChanged<PosterSize> onPosterSizeChanged;
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
                hintText: '搜索片名、路径、格式',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close, size: 18),
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
              color: tokens.surfaceVariant,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.sm),
              ),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(sortKey.label),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SegmentedButton<PosterSize>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
              value: PosterSize.large,
              icon: Icon(Icons.grid_view, size: 18),
              tooltip: '大海报',
            ),
            ButtonSegment(
              value: PosterSize.small,
              icon: Icon(Icons.apps, size: 18),
              tooltip: '小海报',
            ),
          ],
          selected: {posterSize},
          onSelectionChanged: (selection) {
            onPosterSizeChanged(selection.first);
          },
        ),
      ],
    );
  }
}

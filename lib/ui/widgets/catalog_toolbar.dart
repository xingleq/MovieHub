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
              color: tokens.surface.withValues(alpha: 0.5),
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
                BlockIcon.fromMaterial(Icons.sort, size: 24),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  sortKey.label,
                  style: TextStyle(color: tokens.textSecondary),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: tokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _ViewToggle(posterSize: posterSize, onChanged: onPosterSizeChanged),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.posterSize, required this.onChanged});

  final PosterSize posterSize;
  final ValueChanged<PosterSize> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        border: Border.all(color: tokens.cardBorder, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewToggleButton(
            selected: posterSize == PosterSize.large,
            icon: Icons.grid_view,
            onTap: () => onChanged(PosterSize.large),
          ),
          _ViewToggleButton(
            selected: posterSize == PosterSize.small,
            icon: Icons.apps,
            onTap: () => onChanged(PosterSize.small),
          ),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.hover,
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: AppTokens.candyGradient)
              : null,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
          border: selected
              ? Border.all(
                  color: tokens.brickHighlight.withValues(alpha: 0.7),
                  width: 2,
                )
              : null,
        ),
        child: BlockIcon.fromMaterial(icon, size: 24),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';

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
              color: tokens.surface.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.pill),
              ),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort, size: 18, color: tokens.textSecondary),
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
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: Border.all(color: tokens.cardBorder),
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
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : tokens.textSecondary,
        ),
      ),
    );
  }
}

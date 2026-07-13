import 'package:flutter/material.dart';

import '../../app/library_scope.dart';
import '../../core/media/media_group.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import '../widgets/catalog_toolbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/poster_grid.dart';
import '../widgets/section_header.dart';

/// Shared poster-wall page for 动画 / 电影 / 电视剧 / 收藏, rendering grouped
/// entries (a series = one card). Each instance owns its own search query,
/// sort order and poster density.
class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.title,
    required this.groupFilter,
    required this.emptyMessage,
    required this.onOpenEntry,
    required this.onPlayEntry,
  });

  final String title;
  final bool Function(MediaGroup group) groupFilter;
  final String emptyMessage;
  final ValueChanged<MediaGroup> onOpenEntry;
  final ValueChanged<MediaGroup> onPlayEntry;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _searchController = TextEditingController();
  var _sortKey = SortKey.addedAt;
  var _posterSize = PosterSize.large;
  var _selectedFilterIndex = 0;

  static const _filterLabels = ['全部', 'TV动画', '剧场版', 'OVA/OAD', '特别篇'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(MediaGroup group, String query) {
    if (query.isEmpty) {
      return true;
    }
    if (group.title.toLowerCase().contains(query)) {
      return true;
    }
    return group.episodes.any((item) {
      return item.title.toLowerCase().contains(query) ||
          (item.tmdbTitle?.toLowerCase().contains(query) ?? false) ||
          item.path.toLowerCase().contains(query) ||
          item.extension.toLowerCase().contains(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = LibraryScope.of(context);
    final query = _searchController.text.trim().toLowerCase();

    final sectionGroups = groupMediaItems(
      controller.items,
    ).where(widget.groupFilter).toList(growable: false);
    final visibleGroups = sortGroups(
      sectionGroups.where((group) => _matchesQuery(group, query)).toList(),
      _sortKey,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: widget.title,
            trailing: Text(
              '${visibleGroups.length} / ${sectionGroups.length}',
              style: TextStyle(color: AppTokens.of(context).textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _FilterChipBar(
            labels: _filterLabels,
            selectedIndex: _selectedFilterIndex,
            onSelected: (index) => setState(() => _selectedFilterIndex = index),
          ),
          const SizedBox(height: AppSpacing.lg),
          CatalogToolbar(
            searchController: _searchController,
            sortKey: _sortKey,
            posterSize: _posterSize,
            onSortChanged: (key) => setState(() => _sortKey = key),
            onPosterSizeChanged: (size) => setState(() => _posterSize = size),
            onClearSearch: _searchController.clear,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: visibleGroups.isEmpty
                ? EmptyState(
                    icon: Icons.movie_filter_outlined,
                    title: '没有影片',
                    message: query.isEmpty ? widget.emptyMessage : '换个关键词试试。',
                  )
                : PosterGrid(
                    groups: visibleGroups,
                    posterSize: _posterSize,
                    onOpenDetail: widget.onOpenEntry,
                    onPlay: widget.onPlayEntry,
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipBar extends StatelessWidget {
  const _FilterChipBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: AppDurations.hover,
              height: 34,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(colors: AppTokens.candyGradient)
                    : null,
                color: selected ? null : tokens.surface.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.pill),
                ),
                border: Border.all(
                  color: selected ? tokens.accent : tokens.cardBorder,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: tokens.accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ]
                    : const [],
              ),
              child: Center(
                child: Text(
                  labels[index],
                  strutStyle: const StrutStyle(
                    forceStrutHeight: true,
                    height: 1.15,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : tokens.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

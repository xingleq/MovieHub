import 'package:flutter/material.dart';

import '../../app/library_scope.dart';
import '../../theme/app_assets.dart';
import '../../core/media/media_group.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import '../widgets/block_asset.dart';
import '../widgets/catalog_toolbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/poster_grid.dart';

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
    final tokens = AppTokens.of(context);
    final controller = LibraryScope.of(context);
    final query = _searchController.text.trim().toLowerCase();

    final sectionGroups = controller.groups
        .where(widget.groupFilter)
        .toList(growable: false);
    final visibleGroups = sortGroups(
      sectionGroups.where((group) => _matchesQuery(group, query)).toList(),
      _sortKey,
    );
    final titleAsset = switch (widget.title) {
      '动画' || '动画乐园' => AppAssets.animation,
      '电影' => AppAssets.movie,
      '电视剧' => AppAssets.tv,
      _ => AppAssets.favorite,
    };
    // 规范 §4.3：动画=草地绿、电影=魔法紫、电视剧=天空青、收藏=珊瑚红。
    final blockColor = switch (widget.title) {
      '动画' || '动画乐园' => tokens.brickGreen,
      '电影' => tokens.brickPurple,
      '电视剧' => AppTokens.cyanAccent,
      _ => tokens.brickRed,
    };

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
          Row(
            children: [
              _TitleBlock(asset: titleAsset, color: blockColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      query.isEmpty
                          ? '共 ${visibleGroups.length} 部影片'
                          : '找到 ${visibleGroups.length} 部影片',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    illustrationAsset: widget.title.contains('收藏')
                        ? AppAssets.hat
                        : AppAssets.mascot,
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

/// 页面标题前的彩色积木方块：品牌色底 + 高亮描边 + 底部硬阴影，
/// 统一各目录页的视觉锚点（规范 §6/§12）。
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.asset, required this.color});

  final String asset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        border: Border.all(
          color: tokens.brickHighlight.withValues(alpha: 0.66),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.hardShadow,
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: BlockIcon(asset, size: 34),
    );
  }
}

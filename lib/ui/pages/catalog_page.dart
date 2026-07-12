import 'package:flutter/material.dart';

import '../../app/library_scope.dart';
import '../../core/media/media_item.dart';
import '../../theme/app_tokens.dart';
import '../catalog/catalog_options.dart';
import '../widgets/catalog_toolbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/poster_grid.dart';
import '../widgets/section_header.dart';

/// Shared poster-wall page for 电影 / 电视剧 / 收藏. Each instance owns its own
/// search query, sort order and poster density.
class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.title,
    required this.predicate,
    required this.emptyMessage,
    required this.onOpenDetail,
    required this.onPlay,
  });

  final String title;
  final bool Function(MediaItem item) predicate;
  final String emptyMessage;
  final ValueChanged<MediaItem> onOpenDetail;
  final ValueChanged<MediaItem> onPlay;

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

  bool _matchesQuery(MediaItem item, String query) {
    if (query.isEmpty) {
      return true;
    }
    return item.title.toLowerCase().contains(query) ||
        (item.tmdbTitle?.toLowerCase().contains(query) ?? false) ||
        item.path.toLowerCase().contains(query) ||
        item.extension.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final controller = LibraryScope.of(context);
    final tokens = AppTokens.of(context);
    final query = _searchController.text.trim().toLowerCase();

    final sectionItems = controller.items
        .where(widget.predicate)
        .toList(growable: false);
    final visibleItems = sortItems(
      sectionItems.where((item) => _matchesQuery(item, query)).toList(),
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
              '${visibleItems.length} / ${sectionItems.length}',
              style: TextStyle(color: tokens.textSecondary),
            ),
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
            child: visibleItems.isEmpty
                ? EmptyState(
                    icon: Icons.movie_filter_outlined,
                    title: '没有影片',
                    message: query.isEmpty ? widget.emptyMessage : '换个关键词试试。',
                  )
                : PosterGrid(
                    items: visibleItems,
                    posterSize: _posterSize,
                    onOpenDetail: widget.onOpenDetail,
                    onPlay: widget.onPlay,
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/library_scope.dart';
import '../../core/media/media_item.dart';
import '../../theme/app_tokens.dart';
import '../catalog/media_category.dart';
import '../format/formatters.dart';
import '../widgets/continue_watching_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/hero_banner.dart';
import '../widgets/message_banner.dart';
import '../widgets/poster_card.dart';
import '../widgets/shelf_row.dart';

/// Home: hero spotlight plus horizontal shelves (continue watching, recently
/// added, favorites) in a single vertical scroll view.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenDetail,
    required this.onPlay,
    required this.onGoToSettings,
  });

  final ValueChanged<MediaItem> onOpenDetail;
  final ValueChanged<MediaItem> onPlay;
  final VoidCallback onGoToSettings;

  static const _posterShelfCardWidth = 150.0;
  static const _posterShelfHeight = _posterShelfCardWidth * 1.5 + 50;

  @override
  Widget build(BuildContext context) {
    final controller = LibraryScope.of(context);
    final tokens = AppTokens.of(context);

    if (controller.items.isEmpty) {
      return EmptyState(
        icon: Icons.auto_awesome,
        title: '欢迎来到你的小影院 ✨',
        message: controller.roots.isEmpty
            ? '先在设置里添加动画片文件夹，海报墙马上就出现啦。'
            : '目录已添加，去设置中点一下"重新扫描"就好。',
        action: FilledButton.icon(
          onPressed: onGoToSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('前往设置'),
        ),
      );
    }

    final spotlight = controller.spotlightItem;
    final continueWatching = controller.continueWatchingItems;
    final recentlyAdded = controller.recentlyAddedItems;
    final favorites = controller.favoriteItems.take(16).toList(growable: false);
    final animeItems = controller.items
        .where(isAnime)
        .take(16)
        .toList(growable: false);

    final animeCount = controller.items.where(isAnimeSection).length;
    final movieCount = controller.items.where(isMovieSection).length;
    final tvCount = controller.items.where(isTvSection).length;
    final totalSize = controller.items.fold<int>(
      0,
      (sum, item) => sum + item.sizeBytes,
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (controller.error != null) ...[
                MessageBanner(
                  icon: Icons.error_outline,
                  message: controller.error!,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (controller.skippedPaths.isNotEmpty) ...[
                MessageBanner(
                  icon: Icons.warning_amber,
                  message: '有 ${controller.skippedPaths.length} 个路径无法读取或不存在。',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (spotlight != null) ...[
                HeroBanner(
                  item: spotlight,
                  onPlay: () => onPlay(spotlight),
                  onOpenDetail: () => onOpenDetail(spotlight),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (continueWatching.isNotEmpty) ...[
                ShelfRow(
                  title: '继续观看',
                  height: 170,
                  itemCount: continueWatching.length,
                  itemBuilder: (context, index) {
                    final item = continueWatching[index];
                    return ContinueWatchingCard(
                      item: item,
                      onOpenDetail: () => onOpenDetail(item),
                      onPlay: () => onPlay(item),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (animeItems.isNotEmpty) ...[
                ShelfRow(
                  title: '动画乐园 ✨',
                  height: _posterShelfHeight,
                  itemCount: animeItems.length,
                  itemBuilder: (context, index) {
                    final item = animeItems[index];
                    return PosterCard(
                      item: item,
                      width: _posterShelfCardWidth,
                      onOpenDetail: () => onOpenDetail(item),
                      onPlay: () => onPlay(item),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              ShelfRow(
                title: '最近添加',
                height: _posterShelfHeight,
                itemCount: recentlyAdded.length,
                itemBuilder: (context, index) {
                  final item = recentlyAdded[index];
                  return PosterCard(
                    item: item,
                    width: _posterShelfCardWidth,
                    onOpenDetail: () => onOpenDetail(item),
                    onPlay: () => onPlay(item),
                  );
                },
              ),
              if (favorites.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                ShelfRow(
                  title: '我的收藏',
                  height: _posterShelfHeight,
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final item = favorites[index];
                    return PosterCard(
                      item: item,
                      width: _posterShelfCardWidth,
                      onOpenDetail: () => onOpenDetail(item),
                      onPlay: () => onPlay(item),
                    );
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                '媒体库：$animeCount 部动画 · $movieCount 部电影 · $tvCount 集剧集 · '
                '${controller.favoriteCount} 个收藏 · ${formatBytes(totalSize)}',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

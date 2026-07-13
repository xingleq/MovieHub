import 'package:flutter/material.dart';

import '../../app/library_scope.dart';
import '../../core/media/media_group.dart';
import '../../core/media/media_item.dart';
import '../../theme/app_tokens.dart';
import '../catalog/media_category.dart';
import '../widgets/continue_watching_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrance.dart';
import '../widgets/hero_banner.dart';
import '../widgets/message_banner.dart';
import '../widgets/poster_card.dart';
import '../widgets/shelf_row.dart';

/// Home: hero spotlight plus horizontal shelves (continue watching, anime,
/// recently added, favorites) in a single vertical scroll view. Wall shelves
/// render grouped entries — a series is one card.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenEntry,
    required this.onOpenItem,
    required this.onPlayEntry,
    required this.onPlayItem,
    required this.onGoToSettings,
  });

  final ValueChanged<MediaGroup> onOpenEntry;
  final ValueChanged<MediaItem> onOpenItem;
  final ValueChanged<MediaGroup> onPlayEntry;
  final ValueChanged<MediaItem> onPlayItem;
  final VoidCallback onGoToSettings;

  static const _posterShelfCardWidth = 150.0;
  static const _posterShelfHeight = _posterShelfCardWidth * 1.5 + 58;

  @override
  Widget build(BuildContext context) {
    final controller = LibraryScope.of(context);

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

    final groups = controller.groups;
    final animeGroups = groups.where(isAnimeGroup).take(16).toList();
    final recentGroups = [...groups]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final recentlyAdded = recentGroups.take(16).toList();
    final favoriteGroups = groups.where(isFavoriteGroup).take(16).toList();

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
                  onClose: controller.clearError,
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
                Entrance(
                  child: HeroBanner(
                    item: spotlight,
                    onPlay: () => onPlayItem(spotlight),
                    onOpenDetail: () => onOpenItem(spotlight),
                  ),
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
                    return Entrance(
                      delayMs: index.clamp(0, 8) * 40,
                      child: ContinueWatchingCard(
                        item: item,
                        onOpenDetail: () => onOpenItem(item),
                        onPlay: () => onPlayItem(item),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (animeGroups.isNotEmpty) ...[
                _groupShelf('新番速递 ✨', animeGroups),
                const SizedBox(height: AppSpacing.xl),
              ],
              _groupShelf('最近添加', recentlyAdded),
              if (favoriteGroups.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                _groupShelf('我的收藏', favoriteGroups),
              ],
              const SizedBox(height: AppSpacing.xl),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _groupShelf(String title, List<MediaGroup> groups) {
    return ShelfRow(
      title: title,
      height: _posterShelfHeight,
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Entrance(
          delayMs: index.clamp(0, 8) * 40,
          child: PosterCard(
            group: group,
            width: _posterShelfCardWidth,
            onOpenDetail: () => onOpenEntry(group),
            onPlay: () => onPlayEntry(group),
          ),
        );
      },
    );
  }
}

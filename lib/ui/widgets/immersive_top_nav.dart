import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_section.dart';
import '../../core/media/media_group.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_tokens.dart';
import 'cached_tmdb_image.dart';

class ImmersiveTopNav extends StatefulWidget {
  const ImmersiveTopNav({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.searchResults,
    required this.onSearch,
    required this.onOpenResult,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelected;
  final List<MediaGroup> searchResults;
  final ValueChanged<String> onSearch;
  final ValueChanged<MediaGroup> onOpenResult;

  @override
  State<ImmersiveTopNav> createState() => _ImmersiveTopNavState();
}

class _ImmersiveTopNavState extends State<ImmersiveTopNav> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  var _searching = false;
  var _submitted = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    if (_searching) {
      return;
    }
    setState(() {
      _searching = true;
      _submitted = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    widget.onSearch('');
    setState(() {
      _searching = false;
      _submitted = false;
    });
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() => _submitted = true);
    widget.onSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenSearchIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              if (_searching) {
                _closeSearch();
              }
              return null;
            },
          ),
          _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
            onInvoke: (_) {
              _openSearch();
              return null;
            },
          ),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(
              constraints.maxWidth,
              _searching ? 840.0 : 760.0,
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  width: width,
                  height: 58,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: _GlassSurface(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axis: Axis.horizontal,
                            alignment: Alignment.centerLeft,
                            child: child,
                          ),
                        );
                      },
                      child: _searching
                          ? _SearchBar(
                              key: const ValueKey('search'),
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onBack: _closeSearch,
                              onSubmit: _submitSearch,
                            )
                          : _NavigationBar(
                              key: const ValueKey('navigation'),
                              selected: widget.selected,
                              onSearch: _openSearch,
                              onSelected: widget.onSelected,
                            ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _searching && _submitted
                      ? Padding(
                          key: const ValueKey('results'),
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: SizedBox(
                            width: width,
                            child: _SearchResults(
                              results: widget.searchResults,
                              onOpen: (group) {
                                _closeSearch();
                                widget.onOpenResult(group);
                              },
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no-results')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: 0.72),
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.pill),
            ),
            border: Border.all(color: tokens.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    super.key,
    required this.selected,
    required this.onSearch,
    required this.onSelected,
  });

  final AppSection selected;
  final VoidCallback onSearch;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '搜索（Ctrl+K）',
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            color: tokens.cardBorder,
          ),
          for (final section in AppSection.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TextButton.icon(
                onPressed: () => onSelected(section),
                style: TextButton.styleFrom(
                  foregroundColor: section == selected
                      ? Colors.white
                      : tokens.textSecondary,
                  backgroundColor: section == selected
                      ? tokens.accent.withValues(alpha: 0.82)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: AppSpacing.sm,
                  ),
                ),
                icon: Icon(section.icon, size: 17),
                label: Text(_navLabel(section)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onBack,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                hintText: '搜索影片、剧集或文件名',
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onOpen});

  final List<MediaGroup> results;
  final ValueChanged<MediaGroup> onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 390),
            child: results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: Text('没有找到匹配内容')),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    shrinkWrap: true,
                    itemCount: math.min(results.length, 8),
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final group = results[index];
                      final item = group.representative;
                      return ListTile(
                        onTap: () => onOpen(group),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppRadius.md),
                          ),
                        ),
                        leading: SizedBox(
                          width: 42,
                          height: 54,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(AppRadius.sm),
                            ),
                            child: CachedTmdbImage(
                              url:
                                  item.posterPath == null ||
                                      item.posterPath!.isEmpty
                                  ? null
                                  : TmdbClient.posterUrl(item.posterPath!),
                              cacheWidth: 100,
                              placeholderIconSize: 20,
                            ),
                          ),
                        ),
                        title: Text(group.title),
                        subtitle: Text(
                          group.isSeries
                              ? '${group.episodes.length} 集'
                              : item.releaseDate ?? '本地影片',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

String _navLabel(AppSection section) {
  return switch (section) {
    AppSection.anime => '动画',
    AppSection.favorites => '收藏',
    _ => section.title,
  };
}

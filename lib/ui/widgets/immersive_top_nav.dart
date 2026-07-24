import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_section.dart';
import '../../core/media/media_group.dart';
import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import 'block_asset.dart';
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
        SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): DismissIntent(),
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
              constraints.maxWidth - 40,
              _searching ? 980.0 : 900.0,
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  width: width,
                  height: 64,
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
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: 0.82),
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
            border: Border.all(
              color: tokens.brickHighlight.withValues(alpha: 0.62),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.hardShadow.withValues(alpha: 0.42),
                blurRadius: 0,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              child: SvgPicture.asset(AppAssets.brickStuds, height: 28),
            ),
            const _MovieHubWordmark(),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: '搜索（Ctrl+K）',
              onPressed: onSearch,
              icon: const BlockIcon(AppAssets.search, size: 26),
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
                child: _NavigationItem(
                  section: section,
                  selected: section == selected,
                  onPressed: () => onSelected(section),
                ),
              ),
            SizedBox(
              width: 48,
              child: SvgPicture.asset(AppAssets.brickStuds, height: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieHubWordmark extends StatelessWidget {
  const _MovieHubWordmark();

  static const _letters = 'MOVIEHUB';

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final sections = AppSection.values;
    final shadow = Shadow(
      color: tokens.hardShadow.withValues(alpha: 0.35),
      offset: const Offset(1, 1),
    );
    return Text.rich(
      key: const ValueKey('moviehub-wordmark'),
      TextSpan(
        children: [
          for (var index = 0; index < _letters.length; index++)
            TextSpan(
              text: _letters[index],
              style: TextStyle(
                color: sections[index % sections.length].color,
                shadows: [shadow],
              ),
            ),
        ],
      ),
      style: const TextStyle(
        fontFamily: AppFonts.pixelLatin,
        fontSize: 10,
        height: 1,
      ),
    );
  }
}

class _NavigationItem extends StatefulWidget {
  const _NavigationItem({
    required this.section,
    required this.selected,
    required this.onPressed,
  });

  final AppSection section;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<_NavigationItem> {
  final _focusNode = FocusNode();
  var _focused = false;
  var _hovered = false;
  var _pressed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (_focused == _focusNode.hasFocus) {
      return;
    }
    setState(() => _focused = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final sectionColor = widget.section.color;
    // 规范 §9.3：默认态 = 深灰文字 + 彩色小图标；选中态 = 彩色积木底 +
    // 高对比前景（积木黄/天空青等浅底自动切换深色文字）。
    final foreground = widget.selected
        ? widget.section.foreground
        : tokens.textPrimary;
    final iconColor = widget.selected
        ? widget.section.foreground
        : sectionColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed
              ? 0.96
              : _focused
              ? 1.06
              : _hovered
              ? 1.03
              : 1,
          duration: AppDurations.hover,
          curve: Curves.easeOutBack,
          child: TextButton.icon(
            focusNode: _focusNode,
            onPressed: widget.onPressed,
            style:
                TextButton.styleFrom(
                  foregroundColor: foreground,
                  backgroundColor: widget.selected
                      ? sectionColor
                      : _focused || _hovered
                      ? sectionColor.withValues(alpha: 0.15)
                      : tokens.surface.withValues(alpha: 0),
                  shadowColor: sectionColor,
                  elevation: _focused ? 7 : 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.md),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: AppSpacing.sm,
                  ),
                ).copyWith(
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return tokens.brickHighlight.withValues(alpha: 0.2);
                    }
                    if (states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.hovered)) {
                      return tokens.brickHighlight.withValues(alpha: 0.1);
                    }
                    return tokens.surface.withValues(alpha: 0);
                  }),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                      color: _focused
                          ? tokens.brickHighlight
                          : widget.selected
                          ? sectionColor
                          : tokens.surface.withValues(alpha: 0),
                      width: _focused ? 3 : 2,
                    ),
                  ),
                ),
            icon: BlockIcon(
              _sectionAsset(widget.section),
              size: 26,
              color: iconColor,
            ),
            label: Text(
              _navLabel(widget.section),
              style: const TextStyle(
                fontFamily: AppFonts.pixelLabel,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _sectionAsset(AppSection section) {
  return switch (section) {
    AppSection.home => AppAssets.home,
    AppSection.anime => AppAssets.animation,
    AppSection.movies => AppAssets.movie,
    AppSection.tv => AppAssets.tv,
    AppSection.gacha => AppAssets.draw,
    AppSection.favorites => AppAssets.favorite,
    AppSection.settings => AppAssets.settings,
  };
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
            icon: const BlockIcon(AppAssets.back, size: 26),
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
            icon: const BlockIcon(AppAssets.search, size: 24),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        border: Border.all(color: tokens.cardBorder, width: 3),
        boxShadow: [
          BoxShadow(
            color: tokens.accent.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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

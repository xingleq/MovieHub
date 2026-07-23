import 'package:flutter/material.dart';

/// Top-level sections reachable from the navigation rail.
enum AppSection { home, anime, movies, tv, gacha, favorites, settings }

extension AppSectionPresentation on AppSection {
  String get title => switch (this) {
    AppSection.home => '首页',
    AppSection.anime => '动画乐园',
    AppSection.movies => '电影',
    AppSection.tv => '电视剧',
    AppSection.gacha => '抽卡',
    AppSection.favorites => '我的收藏',
    AppSection.settings => '设置',
  };

  IconData get icon => switch (this) {
    AppSection.home => Icons.home_rounded,
    AppSection.anime => Icons.auto_awesome,
    AppSection.movies => Icons.movie_rounded,
    AppSection.tv => Icons.tv_rounded,
    AppSection.gacha => Icons.style_rounded,
    AppSection.favorites => Icons.favorite_rounded,
    AppSection.settings => Icons.settings_rounded,
  };

  /// 积木世界规范 §4.1 调色板：每个分区固定一种品牌色。
  Color get color => switch (this) {
    AppSection.home => const Color(0xFFFFC629),      // 积木黄
    AppSection.anime => const Color(0xFF2DBE60),     // 草地绿
    AppSection.movies => const Color(0xFF8454E8),    // 魔法紫
    AppSection.tv => const Color(0xFF28BFD6),        // 天空青
    AppSection.gacha => const Color(0xFF8454E8),     // 魔法紫（稀有内容）
    AppSection.favorites => const Color(0xFFFF5A4F), // 珊瑚红
    AppSection.settings => const Color(0xFF2D78FF),  // 冒险蓝
  };

  /// 选中态前景色：浅色积木底（积木黄/天空青）配深色文字，其余配白字，
  /// 保证规范 §9.3「白色或深色高对比文字」的对比要求。
  Color get foreground => switch (this) {
    AppSection.home || AppSection.tv => const Color(0xFF1E2A3A),
    _ => const Color(0xFFFFFFFF),
  };
}

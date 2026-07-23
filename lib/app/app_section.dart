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

  Color get color => switch (this) {
    AppSection.home => const Color(0xFF4A90E2),      // 蓝色
    AppSection.anime => const Color(0xFFFF6B9D),     // 粉色
    AppSection.movies => const Color(0xFFF5A623),    // 橙色
    AppSection.tv => const Color(0xFF50E3C2),        // 青色
    AppSection.gacha => const Color(0xFFBD10E0),     // 紫色
    AppSection.favorites => const Color(0xFFFF4757), // 红色
    AppSection.settings => const Color(0xFF7ED321),  // 绿色
  };
}

import 'package:flutter/material.dart';

/// Top-level sections reachable from the navigation rail.
enum AppSection { home, anime, movies, tv, favorites, settings }

extension AppSectionPresentation on AppSection {
  String get title => switch (this) {
    AppSection.home => '首页',
    AppSection.anime => '动画乐园',
    AppSection.movies => '电影',
    AppSection.tv => '电视剧',
    AppSection.favorites => '我的收藏',
    AppSection.settings => '设置',
  };

  IconData get icon => switch (this) {
    AppSection.home => Icons.home_rounded,
    AppSection.anime => Icons.auto_awesome,
    AppSection.movies => Icons.movie_rounded,
    AppSection.tv => Icons.tv_rounded,
    AppSection.favorites => Icons.favorite_rounded,
    AppSection.settings => Icons.settings_rounded,
  };
}

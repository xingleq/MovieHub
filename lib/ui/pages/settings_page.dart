import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/library_controller.dart';
import '../../app/library_scope.dart';
import '../../app/settings_controller.dart';
import '../../app/settings_scope.dart';
import '../../core/gacha/gacha_store.dart';
import '../../core/system/platform_services.dart';
import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import '../widgets/block_asset.dart';
import '../format/formatters.dart';
import '../widgets/message_banner.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _tokenController = TextEditingController();
  final _proxyController = TextEditingController();
  var _fieldsInitialized = false;
  var _category = _SettingsCategory.library;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fieldsInitialized) {
      return;
    }
    final settings = SettingsScope.of(context);
    _tokenController.text = settings.tmdbAccessToken;
    _proxyController.text = settings.tmdbProxy;
    _fieldsInitialized = true;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _proxyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = LibraryScope.of(context);
    final settings = SettingsScope.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(controller: controller),
          const SizedBox(height: AppSpacing.lg),
          if (settings.error != null) ...[
            MessageBanner(
              icon: Icons.error_outline,
              message: settings.error!,
              onClose: settings.clearError,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
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
          Expanded(
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsCategoryNav(
                    selected: _category,
                    onSelected: (category) {
                      setState(() => _category = category);
                    },
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppDurations.fade,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: SingleChildScrollView(
                        key: ValueKey(_category),
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.xxl,
                        ),
                        child: _buildCategoryContent(controller, settings),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(
    LibraryController controller,
    SettingsController settings,
  ) {
    return switch (_category) {
      _SettingsCategory.library => _LibraryTab(
        controller: controller,
        settings: settings,
        embedded: true,
      ),
      _SettingsCategory.scraper => _ScraperTab(
        controller: controller,
        settings: settings,
        proxyController: _proxyController,
        tokenController: _tokenController,
        embedded: true,
      ),
      _SettingsCategory.playback => _PlaybackTab(
        controller: controller,
        settings: settings,
        embedded: true,
      ),
      _SettingsCategory.appearance => _AppearanceTab(
        settings: settings,
        embedded: true,
      ),
      _SettingsCategory.about => const _AboutTab(embedded: true),
    };
  }
}

/// 设置页分类（规范 §16.1）：左侧积木导航的五个固定入口。
enum _SettingsCategory {
  library('媒体库', '管理本地目录、扫描状态和系统数据。', AppAssets.mediaLibrary),
  scraper('刮削与信息', '配置 TMDB 连接和影视资料匹配。', AppAssets.scrape),
  playback('播放与家长控制', '调整轨道偏好、观看限制和额外抽卡次数。', AppAssets.parentalControl),
  appearance('外观', '调整主题、背景和视觉风格。', AppAssets.appearance),
  about('关于', '查看版本和项目使用的核心能力。', AppAssets.dinosaur);

  const _SettingsCategory(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final String icon;

  /// 规范 §4.3 分区色：媒体库=积木黄、刮削=冒险蓝、家长=草地绿、
  /// 外观=魔法紫、关于=天空青。
  Color blockColor(AppTokens tokens) {
    return switch (this) {
      _SettingsCategory.library => tokens.brickYellow,
      _SettingsCategory.scraper => tokens.accent,
      _SettingsCategory.playback => tokens.brickGreen,
      _SettingsCategory.appearance => tokens.brickPurple,
      _SettingsCategory.about => AppTokens.cyanAccent,
    };
  }
}

/// 左侧积木分类导航：白色积木按钮，选中时变为该分类的品牌色积木块。
class _SettingsCategoryNav extends StatelessWidget {
  const _SettingsCategoryNav({
    required this.selected,
    required this.onSelected,
  });

  final _SettingsCategory selected;
  final ValueChanged<_SettingsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 216,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final category in _SettingsCategory.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _SettingsNavItem(
                category: category,
                selected: category == selected,
                onPressed: () => onSelected(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsNavItem extends StatefulWidget {
  const _SettingsNavItem({
    required this.category,
    required this.selected,
    required this.onPressed,
  });

  final _SettingsCategory category;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_SettingsNavItem> createState() => _SettingsNavItemState();
}

class _SettingsNavItemState extends State<_SettingsNavItem> {
  final _focusNode = FocusNode();
  var _focused = false;
  var _hovered = false;
  var _pressed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// 浅色积木底（积木黄/天空青）配深色文字，其余配白字。
  static Color _foregroundOn(Color color) {
    return color.computeLuminance() > 0.55
        ? AppTokens.onLightBrick
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final color = widget.category.blockColor(tokens);
    final selected = widget.selected;
    final highlighted = _hovered || _focused;
    final foreground = selected
        ? _foregroundOn(color)
        : tokens.textPrimary;

    return Tooltip(
      message: widget.category.subtitle,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed
              ? 0.97
              : highlighted && !selected
              ? 1.03
              : 1,
          duration: AppDurations.hover,
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: AppDurations.hover,
            decoration: BoxDecoration(
              color: selected
                  ? color
                  : highlighted
                  ? color.withValues(alpha: 0.14)
                  : tokens.surface.withValues(alpha: 0.78),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              border: Border.all(
                color: _focused
                    ? tokens.accent
                    : selected
                    ? color
                    : tokens.cardBorder,
                width: _focused ? 3 : 2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: tokens.hardShadow,
                        blurRadius: 0,
                        offset: const Offset(4, 4),
                      ),
                    ]
                  : const [],
            ),
            child: InkWell(
              focusNode: _focusNode,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              onTap: widget.onPressed,
              // 分类的一句话说明，悬停可见。
              enableFeedback: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    BlockIcon(
                      widget.category.icon,
                      size: 26,
                      color: selected ? foreground : color,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.category.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final totalSize = controller.items.fold<int>(
      0,
      (sum, item) => sum + item.sizeBytes,
    );

    final title = Row(
      children: [
        const BlockIllustration.mascot(size: 96),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('家长设置中心', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '管理媒体目录、TMDB、播放偏好和本机外观。',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
    final metrics = <Widget>[
      _MetricPill(
        icon: Icons.folder_outlined,
        label: '${controller.roots.length} 个目录',
      ),
      _MetricPill(
        icon: Icons.movie_outlined,
        label: '${controller.items.length} 个视频',
      ),
      _MetricPill(icon: Icons.storage_outlined, label: formatBytes(totalSize)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: metrics,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            for (final (index, metric) in metrics.indexed) ...[
              if (index > 0) const SizedBox(width: AppSpacing.sm),
              metric,
            ],
          ],
        );
      },
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.62),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: Border.all(color: tokens.cardBorder, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tokens.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.controller,
    required this.settings,
    this.embedded = false,
  });

  final LibraryController controller;
  final SettingsController settings;
  final bool embedded;

  /// Runs a scan and reports the outcome. The scan itself already shows
  /// progress (busy bar + button spinner); this closes the loop when done.
  Future<void> _scanAndReport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await controller.scan();
    if (controller.error != null) {
      return; // 失败会显示错误横幅，不再叠加提示。
    }
    final skipped = controller.skippedPaths.length;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          skipped == 0
              ? '扫描完成，媒体库共 ${controller.items.length} 个视频。'
              : '扫描完成，共 ${controller.items.length} 个视频，$skipped 个路径无法读取。',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return _SettingsScrollView(
      embedded: embedded,
      children: [
        _SettingsCard(
          title: '影视目录',
          subtitle: '这些目录会参与本地扫描，可添加多个磁盘路径。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.roots.isEmpty)
                _EmptySettingsState(
                  icon: Icons.folder_open_outlined,
                  message: '还没有添加影视目录。',
                  illustrationAsset: AppAssets.tree,
                )
              else
                for (final root in controller.roots)
                  _PathRow(
                    path: root,
                    onRemove: () => controller.removeRoot(root),
                  ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    autofocus: true,
                    onPressed: controller.selectRoot,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('添加目录'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.roots.isEmpty || controller.scanning
                        ? null
                        : () => unawaited(_scanAndReport(context)),
                    icon: controller.scanning
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(controller.scanning ? '扫描中' : '重新扫描'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _SettingsCard(
          title: '扫描状态',
          subtitle: '扫描会保留已刮削信息、收藏和播放进度。',
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _StatusTile(
                icon: Icons.video_library_outlined,
                label: '视频文件',
                value: '${controller.items.length}',
              ),
              _StatusTile(
                icon: Icons.favorite_outline,
                label: '收藏',
                value: '${controller.favoriteCount}',
              ),
              _StatusTile(
                icon: Icons.warning_amber_outlined,
                label: '跳过路径',
                value: '${controller.skippedPaths.length}',
              ),
            ],
          ),
        ),
        if (PlatformServices.instance.startup.isSupported)
          _SettingsCard(
            title: '系统集成',
            subtitle: '控制 MovieHub 是否在当前 Windows 用户登录后自动启动。',
            child: _SwitchRow(
              icon: Icons.rocket_launch_outlined,
              title: '开机时自动启动 MovieHub',
              subtitle: '开启后写入当前用户启动项，关闭后自动移除。',
              value: settings.launchAtStartup,
              onChanged: settings.setLaunchAtStartup,
            ),
          ),
        _SettingsCard(
          title: '数据位置',
          subtitle: '媒体库使用 SQLite 保存到本机用户目录，令牌和壁纸路径单独保存。',
          child: Text(
            PlatformServices.instance.paths.appDataDirectory.path,
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _ScraperTab extends StatelessWidget {
  const _ScraperTab({
    required this.controller,
    required this.settings,
    required this.proxyController,
    required this.tokenController,
    this.embedded = false,
  });

  final LibraryController controller;
  final SettingsController settings;
  final TextEditingController proxyController;
  final TextEditingController tokenController;
  final bool embedded;

  Future<void> _saveConnection(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await settings.saveTmdbConnection(
      accessToken: tokenController.text,
      proxy: proxyController.text,
    );
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('连接设置已保存。'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return _SettingsScrollView(
      embedded: embedded,
      children: [
        _SettingsCard(
          title: 'TMDB 连接',
          subtitle: '令牌只保存在本机设置文件，不写入项目源码。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: tokenController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'API 读取令牌',
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: settings.hasTmdbToken
                      ? Icon(Icons.check_circle, color: tokens.accent)
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: proxyController,
                decoration: const InputDecoration(
                  labelText: '代理地址（可选）',
                  hintText: '127.0.0.1:7890',
                  prefixIcon: Icon(Icons.lan_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: () => unawaited(_saveConnection(context)),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存连接设置'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed:
                        controller.metadataBatchRunning ||
                            controller.items.isEmpty
                        ? null
                        : controller.matchAllTmdb,
                    icon: controller.metadataBatchRunning
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_sync_outlined),
                    label: const Text('匹配未刮削条目'),
                  ),
                ],
              ),
              if (controller.metadataBatchRunning) ...[
                const SizedBox(height: AppSpacing.lg),
                LinearProgressIndicator(
                  value: controller.metadataBatchTotal == 0
                      ? null
                      : controller.metadataBatchDone /
                            controller.metadataBatchTotal,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '正在匹配 ${controller.metadataBatchDone} / '
                  '${controller.metadataBatchTotal}',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        _SettingsCard(
          title: '刮削内容',
          subtitle: '当前会读取片名、海报、背景图、简介、评分、类型、导演、演员和时长。',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              _CapabilityChip(label: '电影 / 剧集'),
              _CapabilityChip(label: '海报缓存'),
              _CapabilityChip(label: '手动匹配'),
              _CapabilityChip(label: '批量匹配'),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaybackTab extends StatelessWidget {
  const _PlaybackTab({
    required this.controller,
    required this.settings,
    this.embedded = false,
  });

  final LibraryController controller;
  final SettingsController settings;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return _SettingsScrollView(
      embedded: embedded,
      children: [
        _SettingsCard(
          title: '默认轨道',
          subtitle: '播放器打开视频时会按这里的偏好自动选择字幕和音轨。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: settings.subtitlePreference,
                decoration: const InputDecoration(
                  labelText: '默认字幕',
                  prefixIcon: Icon(Icons.subtitles_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'zh-hans', child: Text('简体中文优先')),
                  DropdownMenuItem(value: 'zh-hant', child: Text('繁体中文优先')),
                  DropdownMenuItem(value: 'en', child: Text('英文优先')),
                  DropdownMenuItem(value: 'off', child: Text('默认关闭字幕')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.savePlaybackPreferences(subtitlePreference: value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: settings.audioPreference,
                decoration: const InputDecoration(
                  labelText: '默认音轨',
                  prefixIcon: Icon(Icons.graphic_eq),
                ),
                items: const [
                  DropdownMenuItem(value: 'zh', child: Text('中文优先')),
                  DropdownMenuItem(value: 'ja', child: Text('日语优先')),
                  DropdownMenuItem(value: 'en', child: Text('英语优先')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.savePlaybackPreferences(audioPreference: value);
                  }
                },
              ),
            ],
          ),
        ),
        _SettingsCard(
          title: '家长密码',
          subtitle: '每次进入设置时验证；进入后可修改本页所有受保护项。',
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusTile(
                icon: settings.hasManagementPassword
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                label: '密码状态',
                value: settings.hasManagementPassword ? '已设置' : '未设置',
              ),
              FilledButton.tonalIcon(
                onPressed: () =>
                    _openManagementPasswordDialog(context, settings),
                icon: const Icon(Icons.password_outlined),
                label: Text(settings.hasManagementPassword ? '修改密码' : '设置密码'),
              ),
            ],
          ),
        ),
        _SettingsCard(
          title: '观看与休息',
          subtitle: '仅在视频实际播放时累计；暂停或退出后停止计时，累计达到单次时长才消耗一次并开始强制休息。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _StatusTile(
                    icon: Icons.timer_outlined,
                    label: '单次观看',
                    value: '${settings.watchLimitMinutes} 分钟',
                  ),
                  _StatusTile(
                    icon: Icons.self_improvement,
                    label: '休息时长',
                    value: '${settings.breakMinutes} 分钟',
                  ),
                  _StatusTile(
                    icon: Icons.event_available_outlined,
                    label: '今日已完成',
                    value:
                        '${settings.todayViewingCount}/${settings.todayDailyWatchLimit} · ${settings.todayDayTypeLabel}${settings.hasTodayTemporaryWatchLimit ? ' · 临时' : ''}',
                  ),
                  _StatusTile(
                    icon: Icons.timelapse_outlined,
                    label: '本轮已观看',
                    value: formatDuration(settings.currentViewingElapsed),
                  ),
                  _StatusTile(
                    icon: settings.hasManagementPassword
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    label: '家长密码',
                    value: settings.hasManagementPassword ? '已设置' : '未设置',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _openTodayWatchLimitDialog(context, settings),
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('设置今日临时次数'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _openScreenTimeDialog(context, settings),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('修改默认观看限制'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _GachaDrawsSettingsCard(settings: settings),
        _SettingsCard(
          title: '播放记录',
          subtitle: '退出播放器时自动保存进度；未看完的视频会出现在继续观看。',
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _StatusTile(
                icon: Icons.playlist_play,
                label: '继续观看',
                value: '${controller.continueWatchingItems.length}',
              ),
              _StatusTile(icon: Icons.skip_next, label: '自动下一集', value: '已开启'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openManagementPasswordDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ManagementPasswordDialog(settings: settings),
    );
  }

  Future<void> _openScreenTimeDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ScreenTimeDialog(settings: settings),
    );
  }

  Future<void> _openTodayWatchLimitDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TodayWatchLimitDialog(settings: settings),
    );
  }
}

class _GachaDrawsSettingsCard extends StatefulWidget {
  const _GachaDrawsSettingsCard({required this.settings});

  final SettingsController settings;

  @override
  State<_GachaDrawsSettingsCard> createState() =>
      _GachaDrawsSettingsCardState();
}

class _GachaDrawsSettingsCardState extends State<_GachaDrawsSettingsCard> {
  late Future<GachaSnapshot> _snapshotFuture = _loadSnapshot();

  Future<GachaSnapshot> _loadSnapshot() {
    return Future.microtask(() {
      final store = GachaStore();
      try {
        return store.load();
      } finally {
        store.dispose();
      }
    });
  }

  Future<void> _addDraws() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddGachaDrawsDialog(settings: widget.settings),
    );
    if (mounted) {
      setState(() => _snapshotFuture = _loadSnapshot());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: '抽卡次数',
      subtitle: '每天免费抽一张；家长进入设置后可增加额外抽卡次数。',
      child: FutureBuilder<GachaSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          final bonusDraws = snapshot.data?.bonusDraws ?? 0;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusTile(
                icon: Icons.confirmation_num_outlined,
                label: '额外次数',
                value: '$bonusDraws 次',
              ),
              FilledButton.tonalIcon(
                onPressed: _addDraws,
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('增加抽卡次数'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ManagementPasswordDialog extends StatefulWidget {
  const _ManagementPasswordDialog({required this.settings});

  final SettingsController settings;

  @override
  State<_ManagementPasswordDialog> createState() =>
      _ManagementPasswordDialogState();
}

class _ManagementPasswordDialogState extends State<_ManagementPasswordDialog> {
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return AlertDialog(
      title: Text(settings.hasManagementPassword ? '修改家长密码' : '设置家长密码'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (settings.hasManagementPassword &&
                !settings.settingsUnlocked) ...[
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '当前家长密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新家长密码',
                prefixIcon: Icon(Icons.password_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            final saved = await settings.saveManagementPassword(
              password: _passwordController.text,
              newPassword: _newPasswordController.text,
            );
            if (saved && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _AddGachaDrawsDialog extends StatefulWidget {
  const _AddGachaDrawsDialog({required this.settings});

  final SettingsController settings;

  @override
  State<_AddGachaDrawsDialog> createState() => _AddGachaDrawsDialogState();
}

class _AddGachaDrawsDialogState extends State<_AddGachaDrawsDialog> {
  final _countController = TextEditingController(text: '1');
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _countController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('增加抽卡次数'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '增加次数',
                prefixIcon: Icon(Icons.confirmation_num_outlined),
              ),
            ),
            if (!widget.settings.settingsUnlocked) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '家长密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final count = int.tryParse(_countController.text.trim()) ?? 0;
            if (count <= 0) {
              widget.settings.clearError();
              return;
            }
            if (!widget.settings.settingsUnlocked &&
                !widget.settings.verifyManagementPassword(
                  _passwordController.text,
                )) {
              return;
            }
            final store = GachaStore();
            try {
              store.addBonusDraws(count.clamp(1, 999));
            } finally {
              store.dispose();
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('确认增加'),
        ),
      ],
    );
  }
}

class _TodayWatchLimitDialog extends StatefulWidget {
  const _TodayWatchLimitDialog({required this.settings});

  final SettingsController settings;

  @override
  State<_TodayWatchLimitDialog> createState() => _TodayWatchLimitDialogState();
}

class _TodayWatchLimitDialogState extends State<_TodayWatchLimitDialog> {
  late final TextEditingController _countController;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController(
      text:
          (widget.settings.todayTemporaryWatchLimit ??
                  widget.settings.todayDailyWatchLimit)
              .toString(),
    );
  }

  @override
  void dispose() {
    _countController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save(int? watchLimit) async {
    final saved = await widget.settings.saveTodayTemporaryWatchLimit(
      watchLimit: watchLimit,
      password: _passwordController.text,
    );
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return AlertDialog(
      title: const Text('设置今日临时次数'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '只影响今天；明天自动恢复默认值。今日已完成 ${settings.todayViewingCount} 次。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '今天允许的总次数',
                prefixIcon: Icon(Icons.today_outlined),
              ),
            ),
            if (!settings.settingsUnlocked) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '家长密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (settings.hasTodayTemporaryWatchLimit)
          TextButton(onPressed: () => _save(null), child: const Text('恢复默认')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final count = int.tryParse(_countController.text.trim());
            if (count == null || count < 0) {
              return;
            }
            _save(count);
          },
          child: const Text('保存今日次数'),
        ),
      ],
    );
  }
}

class _ScreenTimeDialog extends StatefulWidget {
  const _ScreenTimeDialog({required this.settings});

  final SettingsController settings;

  @override
  State<_ScreenTimeDialog> createState() => _ScreenTimeDialogState();
}

class _ScreenTimeDialogState extends State<_ScreenTimeDialog> {
  late final TextEditingController _watchController;
  late final TextEditingController _breakController;
  late final TextEditingController _workdayCountController;
  late final TextEditingController _restDayCountController;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _watchController = TextEditingController(
      text: widget.settings.watchLimitMinutes.toString(),
    );
    _breakController = TextEditingController(
      text: widget.settings.breakMinutes.toString(),
    );
    _workdayCountController = TextEditingController(
      text: widget.settings.workdayDailyWatchLimit.toString(),
    );
    _restDayCountController = TextEditingController(
      text: widget.settings.restDayDailyWatchLimit.toString(),
    );
  }

  @override
  void dispose() {
    _watchController.dispose();
    _breakController.dispose();
    _workdayCountController.dispose();
    _restDayCountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('观看限制保护'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _watchController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '单次观看时长（分钟）',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _breakController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '休息时长（分钟）',
                prefixIcon: Icon(Icons.self_improvement),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _workdayCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '工作日/补班次数',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _restDayCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '周末/节假日次数',
                      prefixIcon: Icon(Icons.weekend_outlined),
                    ),
                  ),
                ),
              ],
            ),
            if (!widget.settings.settingsUnlocked) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '家长密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            final saved = await widget.settings.saveScreenTimeLimits(
              watchLimitMinutes:
                  int.tryParse(_watchController.text.trim()) ?? 45,
              breakMinutes: int.tryParse(_breakController.text.trim()) ?? 10,
              workdayDailyWatchLimit:
                  int.tryParse(_workdayCountController.text.trim()) ?? 1,
              restDayDailyWatchLimit:
                  int.tryParse(_restDayCountController.text.trim()) ?? 3,
              password: _passwordController.text,
            );
            if (saved && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab({required this.settings, this.embedded = false});

  final SettingsController settings;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return _SettingsScrollView(
      embedded: embedded,
      children: [
        _SettingsCard(
          title: '主题',
          subtitle: '浅色主题适合白天使用；也可以跟随 Windows 系统设置。',
          child: DropdownButtonFormField<String>(
            initialValue: settings.themeMode,
            decoration: const InputDecoration(
              labelText: '外观模式',
              prefixIcon: Icon(Icons.brightness_6_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'dark', child: Text('深色')),
              DropdownMenuItem(value: 'light', child: Text('浅色')),
              DropdownMenuItem(value: 'system', child: Text('跟随系统')),
            ],
            onChanged: (value) {
              if (value != null) {
                settings.saveThemeMode(value);
              }
            },
          ),
        ),
        _SettingsCard(
          title: '背景',
          subtitle: '可选本地壁纸会被模糊和压暗，避免影响海报墙阅读。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (settings.backgroundImagePath.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.md),
                  ),
                  child: Image.file(
                    File(settings.backgroundImagePath),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 72,
                        alignment: Alignment.center,
                        color: tokens.surfaceVariant,
                        child: const Text('背景图片无法读取'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  settings.backgroundImagePath,
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ] else
                _EmptySettingsState(
                  icon: Icons.wallpaper_outlined,
                  message: '当前使用默认浅蓝动态背景。',
                  illustrationAsset: AppAssets.flower,
                ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: settings.pickBackgroundImage,
                    icon: const Icon(Icons.wallpaper),
                    label: const Text('选择本地壁纸'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: settings.backgroundImagePath.isEmpty
                        ? null
                        : settings.clearBackgroundImage,
                    icon: const Icon(Icons.format_color_reset),
                    label: const Text('恢复默认背景'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _SettingsCard(
          title: '视觉风格',
          subtitle: '当前分为深色和浅色风格',
          child: Row(
            children: [
              for (final color in [
                tokens.accent,
                AppTokens.candyGradient.last,
                AppTokens.cyanAccent,
                tokens.surface,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadius.sm),
                      ),
                      border: Border.all(color: tokens.cardBorder),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return _SettingsScrollView(
      embedded: embedded,
      children: [
        _SettingsCard(
          title: 'MovieHub',
          subtitle: '本地优先的私人影视库。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本：1.2.0', style: TextStyle(color: tokens.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: const [
                  _CapabilityChip(label: 'Flutter'),
                  _CapabilityChip(label: 'SQLite'),
                  _CapabilityChip(label: 'media_kit'),
                  _CapabilityChip(label: 'TMDB'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton.icon(
                onPressed: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'MovieHub',
                    applicationVersion: '1.2.0',
                  );
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('查看应用信息'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsScrollView extends StatelessWidget {
  const _SettingsScrollView({required this.children, this.embedded = false});

  final List<Widget> children;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('settings-card-flow'),
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 980;
        final content = twoColumns
            ? KeyedSubtree(
                key: const ValueKey('settings-two-column-grid'),
                child: _TwoColumnSettingsGrid(children: children),
              )
            : KeyedSubtree(
                key: const ValueKey('settings-single-column'),
                child: _SettingsColumn(children: children),
              );
        if (embedded) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: content,
          );
        }
        if (!twoColumns) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [content],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: content,
        );
      },
    );
  }
}

class _TwoColumnSettingsGrid extends StatelessWidget {
  const _TwoColumnSettingsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index += 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[index]),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: index + 1 < children.length
                    ? children[index + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _SettingsColumn extends StatelessWidget {
  const _SettingsColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children) ...[
          child,
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _SettingsCard extends StatefulWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  var _focused = false;

  void _handleFocusChange(bool focused) {
    if (_focused == focused) {
      return;
    }
    setState(() => _focused = focused);
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.32,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Focus(
      canRequestFocus: false,
      onFocusChange: _handleFocusChange,
      child: AnimatedScale(
        scale: _focused ? 1.04 : 1,
        duration: AppDurations.hover,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: AppDurations.hover,
          decoration: BoxDecoration(
            color: _focused
                ? tokens.surface
                : tokens.surface.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
            border: Border.all(
              color: _focused ? tokens.accent : tokens.cardBorder,
              width: _focused ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.accent.withValues(alpha: _focused ? 0.24 : 0.1),
                blurRadius: _focused ? 28 : 18,
                offset: Offset(0, _focused ? 10 : 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.subtitle,
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.lg),
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: tokens.surfaceVariant.withValues(alpha: 0.72),
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          border: Border.all(color: tokens.cardBorder, width: 2),
        ),
        child: Row(
          children: [
            const BlockIcon(AppAssets.folder, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              tooltip: '移除目录',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant.withValues(alpha: 0.64),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        border: Border.all(color: tokens.cardBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: tokens.hardShadow.withValues(alpha: 0.7),
            blurRadius: 0,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.sm),
              ),
            ),
            child: BlockIcon.fromMaterial(icon, size: 26),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        border: Border.all(color: tokens.cardBorder, width: 2),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.surfaceVariant.withValues(alpha: 0.72),
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
            border: Border.all(color: tokens.cardBorder, width: 2),
          ),
          child: BlockIcon.fromMaterial(icon, size: 26),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _EmptySettingsState extends StatelessWidget {
  const _EmptySettingsState({
    required this.icon,
    required this.message,
    this.illustrationAsset,
  });

  final IconData icon;
  final String message;
  final String? illustrationAsset;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant.withValues(alpha: 0.46),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        border: Border.all(color: tokens.cardBorder, width: 2),
      ),
      child: Row(
        children: [
          if (illustrationAsset case final asset?)
            BlockIllustration(asset: asset, size: 88, semanticLabel: message)
          else
            BlockIcon.fromMaterial(icon, size: 30),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(message, style: TextStyle(color: tokens.textSecondary)),
          ),
        ],
      ),
    );
  }
}

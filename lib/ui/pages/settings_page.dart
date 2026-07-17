import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/library_controller.dart';
import '../../app/library_scope.dart';
import '../../app/settings_controller.dart';
import '../../app/settings_scope.dart';
import '../../core/gacha/gacha_store.dart';
import '../../theme/app_tokens.dart';
import '../format/formatters.dart';
import '../widgets/message_banner.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin {
  final _tokenController = TextEditingController();
  final _proxyController = TextEditingController();
  late final TabController _tabController;
  var _fieldsInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

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
    _tabController.dispose();
    _tokenController.dispose();
    _proxyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = LibraryScope.of(context);
    final settings = SettingsScope.of(context);
    final tokens = AppTokens.of(context);

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
          _SettingsTabBar(controller: _tabController),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.18),
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.lg),
                ),
                border: Border.all(color: tokens.cardBorder),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _LibraryTab(controller: controller, settings: settings),
                  _ScraperTab(
                    controller: controller,
                    settings: settings,
                    proxyController: _proxyController,
                    tokenController: _tokenController,
                  ),
                  _PlaybackTab(controller: controller, settings: settings),
                  _AppearanceTab(settings: settings),
                  const _AboutTab(),
                ],
              ),
            ),
          ),
        ],
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '设置',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '管理媒体目录、TMDB、播放偏好和本机外观。',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
        _MetricPill(
          icon: Icons.folder_outlined,
          label: '${controller.roots.length} 个目录',
        ),
        const SizedBox(width: AppSpacing.sm),
        _MetricPill(
          icon: Icons.movie_outlined,
          label: '${controller.items.length} 个视频',
        ),
        const SizedBox(width: AppSpacing.sm),
        _MetricPill(
          icon: Icons.storage_outlined,
          label: formatBytes(totalSize),
        ),
      ],
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
        border: Border.all(color: tokens.cardBorder),
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

class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar({required this.controller});

  final TabController controller;

  static const _tabs = [
    (Icons.folder_outlined, '媒体库'),
    (Icons.cloud_sync_outlined, '刮削'),
    (Icons.play_circle_outline, '播放'),
    (Icons.palette_outlined, '外观'),
    (Icons.info_outline, '关于'),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: tokens.surface.withValues(alpha: 0.52),
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            gradient: const LinearGradient(colors: AppTokens.candyGradient),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: tokens.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            for (final (icon, label) in _tabs)
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Text(label),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({required this.controller, required this.settings});

  final LibraryController controller;
  final SettingsController settings;

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
            Platform.isWindows ? r'%APPDATA%\MovieHub' : '~/.moviehub',
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
  });

  final LibraryController controller;
  final SettingsController settings;
  final TextEditingController proxyController;
  final TextEditingController tokenController;

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
  const _PlaybackTab({required this.controller, required this.settings});

  final LibraryController controller;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return _SettingsScrollView(
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
          title: '管理密码',
          subtitle: '单独管理家长密码；观看时长和抽卡次数都会使用它校验。',
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
          subtitle: '进入播放器后开始计时，到时会锁定整个软件并显示休息倒计时。',
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
                    icon: settings.hasManagementPassword
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    label: '管理密码',
                    value: settings.hasManagementPassword ? '已设置' : '未设置',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => _openScreenTimeDialog(context, settings),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('修改观看时长'),
                ),
              ),
            ],
          ),
        ),
        _SettingsCard(
          title: '抽卡次数',
          subtitle: '每天免费抽一张；这里可以输入管理密码给当前用户增加额外抽卡次数。',
          child: FutureBuilder<GachaSnapshot>(
            future: Future(() {
              final store = GachaStore();
              try {
                return store.load();
              } finally {
                store.dispose();
              }
            }),
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
                    onPressed: () =>
                        _openAddGachaDrawsDialog(context, settings),
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('增加抽卡次数'),
                  ),
                ],
              );
            },
          ),
        ),
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

  Future<void> _openAddGachaDrawsDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddGachaDrawsDialog(settings: settings),
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
      title: Text(settings.hasManagementPassword ? '修改管理密码' : '设置管理密码'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (settings.hasManagementPassword) ...[
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '当前管理密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新管理密码',
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
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '管理密码',
                prefixIcon: Icon(Icons.lock_outline),
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
          onPressed: () {
            final count = int.tryParse(_countController.text.trim()) ?? 0;
            if (count <= 0) {
              widget.settings.clearError();
              return;
            }
            if (!widget.settings.verifyManagementPassword(
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

class _ScreenTimeDialog extends StatefulWidget {
  const _ScreenTimeDialog({required this.settings});

  final SettingsController settings;

  @override
  State<_ScreenTimeDialog> createState() => _ScreenTimeDialogState();
}

class _ScreenTimeDialogState extends State<_ScreenTimeDialog> {
  late final TextEditingController _watchController;
  late final TextEditingController _breakController;
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
  }

  @override
  void dispose() {
    _watchController.dispose();
    _breakController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('观看时长保护'),
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
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '管理密码',
                prefixIcon: Icon(Icons.lock_outline),
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
            final saved = await widget.settings.saveScreenTimeLimits(
              watchLimitMinutes:
                  int.tryParse(_watchController.text.trim()) ?? 45,
              breakMinutes: int.tryParse(_breakController.text.trim()) ?? 10,
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
  const _AppearanceTab({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return _SettingsScrollView(
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
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return _SettingsScrollView(
      children: [
        _SettingsCard(
          title: 'MovieHub',
          subtitle: '本地优先的 Windows 私人影视库。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本：1.1.1', style: TextStyle(color: tokens.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: const [
                  _CapabilityChip(label: 'Flutter Windows'),
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
                    applicationVersion: '1.1.1',
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
  const _SettingsScrollView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 980;
        if (!twoColumns) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          );
        }

        final left = <Widget>[];
        final right = <Widget>[];
        for (final (index, child) in children.indexed) {
          (index.isEven ? left : right).add(child);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _SettingsColumn(children: left)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _SettingsColumn(children: right)),
            ],
          ),
        );
      },
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        border: Border.all(color: tokens.cardBorder),
        boxShadow: [
          BoxShadow(
            color: tokens.accent.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
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
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, color: tokens.textSecondary),
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
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tokens.textSecondary),
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
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: Border.all(color: tokens.cardBorder),
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
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Icon(icon, size: 20, color: tokens.textSecondary),
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
  const _EmptySettingsState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant.withValues(alpha: 0.46),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: tokens.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(message, style: TextStyle(color: tokens.textSecondary)),
          ),
        ],
      ),
    );
  }
}

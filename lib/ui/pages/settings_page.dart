import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/library_scope.dart';
import '../../theme/app_tokens.dart';
import '../widgets/message_banner.dart';

/// Full settings page: library folders, scanning, TMDB credentials and batch
/// matching, plus the about entry.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _tokenController = TextEditingController();
  final _proxyController = TextEditingController();
  var _fieldsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fieldsInitialized) {
      final controller = LibraryScope.of(context);
      _tokenController.text = controller.tmdbAccessToken;
      _proxyController.text = controller.tmdbProxy;
      _fieldsInitialized = true;
    }
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
    final tokens = AppTokens.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '设置',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('媒体库与 TMDB', style: TextStyle(color: tokens.textSecondary)),
              const SizedBox(height: AppSpacing.xl),
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
              _SettingsCard(
                title: '媒体库目录',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.roots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          '尚未添加目录。选择一个或多个本地影视文件夹后开始扫描。',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      )
                    else
                      for (final root in controller.roots)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(
                            root,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: '移除目录',
                            onPressed: () => controller.removeRoot(root),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: controller.selectRoot,
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('添加目录'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                controller.roots.isEmpty || controller.scanning
                                ? null
                                : controller.scan,
                            icon: controller.scanning
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            label: Text(controller.scanning ? '扫描中…' : '重新扫描'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SettingsCard(
                title: 'TMDB 刮削',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _proxyController,
                      decoration: const InputDecoration(
                        labelText: '代理（可选）',
                        hintText: '127.0.0.1:7890',
                        prefixIcon: Icon(Icons.lan_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _tokenController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'API 读取令牌',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: controller.hasTmdbToken
                            ? const Icon(Icons.check_circle_outline)
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              controller.saveTmdbSettings(
                                accessToken: _tokenController.text,
                                proxy: _proxyController.text,
                              );
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('保存 TMDB 设置'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed:
                                controller.metadataBatchRunning ||
                                    controller.items.isEmpty
                                ? null
                                : controller.matchAllTmdb,
                            icon: controller.metadataBatchRunning
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cloud_sync_outlined),
                            label: const Text('匹配全部'),
                          ),
                        ),
                      ],
                    ),
                    if (controller.metadataBatchRunning) ...[
                      const SizedBox(height: AppSpacing.md),
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
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SettingsCard(
                title: '外观',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '选一张自己喜欢的动漫壁纸铺在整个应用底下（仅本机使用）。',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (controller.backgroundImagePath.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadius.md),
                        ),
                        child: Image.file(
                          File(controller.backgroundImagePath),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 64,
                              alignment: Alignment.center,
                              color: tokens.surfaceVariant,
                              child: const Text('背景图片无法读取'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: controller.pickBackgroundImage,
                            icon: const Icon(Icons.wallpaper),
                            label: const Text('选择背景图片'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: controller.backgroundImagePath.isEmpty
                                ? null
                                : controller.clearBackgroundImage,
                            icon: const Icon(Icons.format_color_reset),
                            label: const Text('恢复纯色背景'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SettingsCard(
                title: '关于',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_fill),
                  title: const Text('MovieHub'),
                  subtitle: Text(
                    '0.1.0 · 私人电影院',
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'MovieHub',
                        applicationVersion: '0.1.0',
                      );
                    },
                    child: const Text('详情'),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

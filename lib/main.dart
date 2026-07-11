import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'core/media/media_item.dart';
import 'core/media/media_library_store.dart';
import 'core/media/media_scanner.dart';
import 'core/tmdb/tmdb_client.dart';
import 'core/tmdb/tmdb_settings_store.dart';

void main() {
  runApp(const MovieHubApp());
}

class MovieHubApp extends StatelessWidget {
  const MovieHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE50914),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'MovieHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF101113),
        cardTheme: const CardThemeData(
          color: Color(0xFF191B1F),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = MediaLibraryStore();
  final _scanner = MediaScanner();
  final _tmdbClient = TmdbClient();
  final _settingsStore = TmdbSettingsStore();
  final _searchController = TextEditingController();
  final _tmdbTokenController = TextEditingController();
  final _tmdbProxyController = TextEditingController();

  var _roots = <String>[];
  var _items = <MediaItem>[];
  var _skippedPaths = <String>[];
  var _loading = true;
  var _scanning = false;
  var _query = '';
  var _favoritesOnly = false;
  var _tmdbAccessToken = '';
  var _tmdbProxy = '';
  String? _metadataLoadingPath;
  MediaItem? _selectedItem;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
    _loadAppState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tmdbTokenController.dispose();
    _tmdbProxyController.dispose();
    super.dispose();
  }

  List<MediaItem> get _filteredItems {
    return _items.where((item) {
      if (_favoritesOnly && !item.favorite) {
        return false;
      }
      if (_query.isEmpty) {
        return true;
      }
      return item.title.toLowerCase().contains(_query) ||
          item.path.toLowerCase().contains(_query) ||
          item.extension.toLowerCase().contains(_query);
    }).toList();
  }

  int get _favoriteCount {
    return _items.where((item) => item.favorite).length;
  }

  Future<void> _loadAppState() async {
    try {
      final snapshot = await _store.load();
      final settings = await _settingsStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _roots = snapshot.roots;
        _items = snapshot.items;
        _selectedItem = snapshot.items.isEmpty ? null : snapshot.items.first;
        _tmdbAccessToken = settings.accessToken;
        _tmdbProxy = settings.proxy;
        _tmdbTokenController.text = settings.accessToken;
        _tmdbProxyController.text = settings.proxy;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '读取媒体库失败：$error';
        _loading = false;
      });
    }
  }

  Future<void> _saveTmdbToken() async {
    final token = _tmdbTokenController.text.trim();
    final proxy = _tmdbProxyController.text.trim();
    await _settingsStore.save(TmdbSettings(accessToken: token, proxy: proxy));

    setState(() {
      _tmdbAccessToken = token;
      _tmdbProxy = proxy;
      _error = null;
    });
  }

  Future<void> _selectRoot() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择影视文件夹',
      lockParentWindow: true,
    );
    if (path == null || path.trim().isEmpty || _roots.contains(path)) {
      return;
    }

    final updatedRoots = [..._roots, path];
    await _store.save(MediaLibrarySnapshot(roots: updatedRoots, items: _items));

    setState(() {
      _roots = updatedRoots;
    });
  }

  Future<void> _removeRoot(String path) async {
    final updatedRoots = _roots.where((root) => root != path).toList();
    await _store.save(MediaLibrarySnapshot(roots: updatedRoots, items: _items));

    setState(() {
      _roots = updatedRoots;
    });
  }

  Future<void> _scan() async {
    if (_roots.isEmpty || _scanning) {
      return;
    }

    setState(() {
      _scanning = true;
      _error = null;
      _skippedPaths = [];
    });

    try {
      final result = await _scanner.scanRoots(_roots, existingItems: _items);
      await _store.save(
        MediaLibrarySnapshot(roots: _roots, items: result.items),
      );

      if (!mounted) {
        return;
      }
      final selectedPath = _selectedItem?.path;
      MediaItem? nextSelectedItem;
      if (selectedPath != null) {
        for (final item in result.items) {
          if (item.path == selectedPath) {
            nextSelectedItem = item;
            break;
          }
        }
      }

      setState(() {
        _items = result.items;
        _selectedItem =
            nextSelectedItem ??
            (result.items.isEmpty ? null : result.items.first);
        _skippedPaths = result.skippedPaths;
        _scanning = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '扫描失败：$error';
        _scanning = false;
      });
    }
  }

  Future<void> _openItemLocation(MediaItem item) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,', item.path]);
        return;
      }

      if (Platform.isMacOS) {
        await Process.start('open', ['-R', item.path]);
        return;
      }

      await Process.start('xdg-open', [File(item.path).parent.path]);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '打开文件位置失败：$error';
      });
    }
  }

  Future<void> _toggleFavorite(MediaItem item) async {
    final updatedItems = _items.map((current) {
      if (current.path != item.path) {
        return current;
      }
      return current.copyWith(favorite: !current.favorite);
    }).toList();

    MediaItem? updatedSelectedItem;
    for (final updatedItem in updatedItems) {
      if (updatedItem.path == _selectedItem?.path) {
        updatedSelectedItem = updatedItem;
        break;
      }
    }

    await _store.save(MediaLibrarySnapshot(roots: _roots, items: updatedItems));

    setState(() {
      _items = updatedItems;
      _selectedItem = updatedSelectedItem;
    });
  }

  Future<void> _matchTmdb(MediaItem item) async {
    if (_tmdbAccessToken.trim().isEmpty) {
      setState(() {
        _error = '请先保存 TMDB 令牌。';
      });
      return;
    }

    setState(() {
      _metadataLoadingPath = item.path;
      _error = null;
    });

    try {
      final match = await _tmdbClient.searchMovie(
        accessToken: _tmdbAccessToken,
        query: item.title,
        proxy: _tmdbProxy,
      );

      if (match == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _metadataLoadingPath = null;
          _error = 'TMDB 未找到匹配结果：${item.title}';
        });
        return;
      }

      final updatedItems = _items.map((current) {
        if (current.path != item.path) {
          return current;
        }
        return current.copyWith(
          tmdbId: match.id,
          tmdbTitle: match.title,
          overview: match.overview,
          posterPath: match.posterPath,
          backdropPath: match.backdropPath,
          releaseDate: match.releaseDate,
          voteAverage: match.voteAverage,
        );
      }).toList();

      MediaItem? updatedSelectedItem;
      for (final updatedItem in updatedItems) {
        if (updatedItem.path == _selectedItem?.path) {
          updatedSelectedItem = updatedItem;
          break;
        }
      }

      await _store.save(
        MediaLibrarySnapshot(roots: _roots, items: updatedItems),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _items = updatedItems;
        _selectedItem = updatedSelectedItem;
        _metadataLoadingPath = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _metadataLoadingPath = null;
        _error = 'TMDB 匹配失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 360,
                child: _LibraryPanel(
                  roots: _roots,
                  scanning: _scanning,
                  tmdbTokenController: _tmdbTokenController,
                  tmdbProxyController: _tmdbProxyController,
                  hasTmdbToken: _tmdbAccessToken.isNotEmpty,
                  onSelectRoot: _selectRoot,
                  onRemoveRoot: _removeRoot,
                  onScan: _scan,
                  onSaveTmdbToken: _saveTmdbToken,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _MediaShelf(
                  items: _filteredItems,
                  totalItems: _items.length,
                  favoriteCount: _favoriteCount,
                  searchController: _searchController,
                  favoritesOnly: _favoritesOnly,
                  selectedItem: _selectedItem,
                  metadataLoadingPath: _metadataLoadingPath,
                  skippedPaths: _skippedPaths,
                  error: _error,
                  onSelectItem: (item) {
                    setState(() {
                      _selectedItem = item;
                    });
                  },
                  onClearSearch: _searchController.clear,
                  onFavoritesOnlyChanged: (value) {
                    setState(() {
                      _favoritesOnly = value;
                    });
                  },
                  onToggleFavorite: _toggleFavorite,
                  onMatchTmdb: _matchTmdb,
                  onOpenLocation: _openItemLocation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel({
    required this.roots,
    required this.scanning,
    required this.tmdbTokenController,
    required this.tmdbProxyController,
    required this.hasTmdbToken,
    required this.onSelectRoot,
    required this.onRemoveRoot,
    required this.onScan,
    required this.onSaveTmdbToken,
  });

  final List<String> roots;
  final bool scanning;
  final TextEditingController tmdbTokenController;
  final TextEditingController tmdbProxyController;
  final bool hasTmdbToken;
  final VoidCallback onSelectRoot;
  final ValueChanged<String> onRemoveRoot;
  final VoidCallback onScan;
  final VoidCallback onSaveTmdbToken;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'MovieHub',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '本地影视库',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onSelectRoot,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('选择目录'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: '重新扫描',
              onPressed: roots.isEmpty || scanning ? null : onScan,
              icon: scanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: tmdbProxyController,
          decoration: const InputDecoration(
            labelText: '代理（可选）',
            hintText: '127.0.0.1:7890',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lan_outlined),
          ),
        ),
        const SizedBox(height: 24),
        Text('TMDB', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: tmdbTokenController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'API 读取令牌',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: hasTmdbToken
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: '保存 TMDB 令牌',
              onPressed: onSaveTmdbToken,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('媒体库目录', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Expanded(
          child: roots.isEmpty
              ? const _EmptyState(
                  icon: Icons.folder_open,
                  title: '尚未添加目录',
                  message: '选择一个或多个本地影视文件夹后开始扫描。',
                )
              : ListView.separated(
                  itemCount: roots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final root = roots[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(
                          root,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: '移除目录',
                          onPressed: () => onRemoveRoot(root),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MediaShelf extends StatelessWidget {
  const _MediaShelf({
    required this.items,
    required this.totalItems,
    required this.favoriteCount,
    required this.searchController,
    required this.favoritesOnly,
    required this.selectedItem,
    required this.metadataLoadingPath,
    required this.skippedPaths,
    required this.error,
    required this.onSelectItem,
    required this.onClearSearch,
    required this.onFavoritesOnlyChanged,
    required this.onToggleFavorite,
    required this.onMatchTmdb,
    required this.onOpenLocation,
  });

  final List<MediaItem> items;
  final int totalItems;
  final int favoriteCount;
  final TextEditingController searchController;
  final bool favoritesOnly;
  final MediaItem? selectedItem;
  final String? metadataLoadingPath;
  final List<String> skippedPaths;
  final String? error;
  final ValueChanged<MediaItem> onSelectItem;
  final VoidCallback onClearSearch;
  final ValueChanged<bool> onFavoritesOnlyChanged;
  final ValueChanged<MediaItem> onToggleFavorite;
  final ValueChanged<MediaItem> onMatchTmdb;
  final ValueChanged<MediaItem> onOpenLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatsBar(items: items, favoriteCount: favoriteCount),
        const SizedBox(height: 20),
        if (error != null) ...[
          _MessageBanner(icon: Icons.error_outline, message: error!),
          const SizedBox(height: 12),
        ],
        if (skippedPaths.isNotEmpty) ...[
          _MessageBanner(
            icon: Icons.warning_amber,
            message: '有 ${skippedPaths.length} 个路径无法读取或不存在。',
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                '影片库',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(
              '${items.length} / $totalItems',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: '搜索片名、路径、格式',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.grid_view),
                  label: Text('全部'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.favorite),
                  label: Text('收藏'),
                ),
              ],
              selected: {favoritesOnly},
              onSelectionChanged: (selection) {
                onFavoritesOnlyChanged(selection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: items.isEmpty
              ? const _EmptyState(
                  icon: Icons.movie_filter_outlined,
                  title: '还没有影片',
                  message: '添加目录并扫描后，或调整搜索条件后重试。',
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = (constraints.maxWidth / 220)
                              .floor()
                              .clamp(2, 5)
                              .toInt();
                          return GridView.builder(
                            itemCount: items.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 0.72,
                                ),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _MediaCard(
                                item: item,
                                selected: item.path == selectedItem?.path,
                                onTap: () => onSelectItem(item),
                                onToggleFavorite: () => onToggleFavorite(item),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 320,
                      child: _MediaDetailPanel(
                        item: selectedItem,
                        loadingMetadata:
                            selectedItem?.path == metadataLoadingPath,
                        onToggleFavorite: onToggleFavorite,
                        onMatchTmdb: onMatchTmdb,
                        onOpenLocation: onOpenLocation,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.items, required this.favoriteCount});

  final List<MediaItem> items;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    final totalSize = items.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    return Row(
      children: [
        _StatCard(label: '影片', value: '${items.length}'),
        const SizedBox(width: 12),
        _StatCard(label: '收藏', value: '$favoriteCount'),
        const SizedBox(width: 12),
        _StatCard(label: '容量', value: _formatBytes(totalSize)),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final MediaItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        side: BorderSide(
          color: selected ? colorScheme.primary : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2D3036), Color(0xFF111216)],
                        ),
                      ),
                      child: const Icon(Icons.movie, size: 52),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: item.favorite ? '取消收藏' : '收藏',
                      onPressed: onToggleFavorite,
                      icon: Icon(
                        item.favorite ? Icons.favorite : Icons.favorite_border,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.tmdbTitle ?? item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.extension.toUpperCase()}  ${formatDate(item.addedAt)}',
                    style: TextStyle(color: colorScheme.outline, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.path,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.outline, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _MediaDetailPanel extends StatelessWidget {
  const _MediaDetailPanel({
    required this.item,
    required this.loadingMetadata,
    required this.onToggleFavorite,
    required this.onMatchTmdb,
    required this.onOpenLocation,
  });

  final MediaItem? item;
  final bool loadingMetadata;
  final ValueChanged<MediaItem> onToggleFavorite;
  final ValueChanged<MediaItem> onMatchTmdb;
  final ValueChanged<MediaItem> onOpenLocation;

  @override
  Widget build(BuildContext context) {
    final selectedItem = item;
    if (selectedItem == null) {
      return const _EmptyState(
        icon: Icons.info_outline,
        title: '未选择影片',
        message: '选择一部影片后查看文件详情。',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PosterPreview(item: selectedItem),
            const SizedBox(height: 18),
            Text(
              selectedItem.tmdbTitle ?? selectedItem.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (selectedItem.tmdbTitle != null &&
                selectedItem.tmdbTitle != selectedItem.title) ...[
              const SizedBox(height: 6),
              Text(
                selectedItem.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
            const SizedBox(height: 18),
            if (selectedItem.tmdbId != null) ...[
              _DetailRow(label: 'TMDB', value: '#${selectedItem.tmdbId}'),
              _DetailRow(
                label: '评分',
                value: selectedItem.voteAverage == null
                    ? '-'
                    : selectedItem.voteAverage!.toStringAsFixed(1),
              ),
              _DetailRow(label: '上映', value: selectedItem.releaseDate ?? '-'),
            ],
            _DetailRow(
              label: '格式',
              value: selectedItem.extension.toUpperCase(),
            ),
            _DetailRow(
              label: '大小',
              value: _StatsBar._formatBytes(selectedItem.sizeBytes),
            ),
            _DetailRow(
              label: '添加',
              value: _MediaCard.formatDate(selectedItem.addedAt),
            ),
            _DetailRow(
              label: '修改',
              value: _MediaCard.formatDate(selectedItem.modifiedAt),
            ),
            if (selectedItem.overview != null &&
                selectedItem.overview!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '简介',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 6),
              Text(
                selectedItem.overview!,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '文件路径',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 6),
            SelectableText(
              selectedItem.path,
              style: const TextStyle(fontSize: 12),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: loadingMetadata
                  ? null
                  : () => onMatchTmdb(selectedItem),
              icon: loadingMetadata
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_outlined),
              label: Text(selectedItem.tmdbId == null ? '匹配 TMDB' : '重新匹配'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => onToggleFavorite(selectedItem),
                    icon: Icon(
                      selectedItem.favorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                    label: Text(selectedItem.favorite ? '已收藏' : '收藏'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onOpenLocation(selectedItem),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('打开位置'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterPreview extends StatelessWidget {
  const _PosterPreview({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final posterPath = item.posterPath;
    if (posterPath != null && posterPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Image.network(
          TmdbClient.posterUrl(posterPath),
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const _PosterPlaceholder(height: 220);
          },
        ),
      );
    }

    return const _PosterPlaceholder(height: 170);
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF30343B), Color(0xFF15161A)],
        ),
      ),
      child: const Icon(Icons.local_movies_outlined, size: 64),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF231E14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFC857)),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'core/media/media_item.dart';
import 'core/media/media_library_store.dart';
import 'core/media/media_scanner.dart';

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
  final _pathController = TextEditingController();

  var _roots = <String>[];
  var _items = <MediaItem>[];
  var _skippedPaths = <String>[];
  var _loading = true;
  var _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    try {
      final snapshot = await _store.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _roots = snapshot.roots;
        _items = snapshot.items;
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

  Future<void> _addRoot() async {
    final path = _pathController.text.trim();
    if (path.isEmpty || _roots.contains(path)) {
      return;
    }

    final updatedRoots = [..._roots, path];
    await _store.save(MediaLibrarySnapshot(roots: updatedRoots, items: _items));

    setState(() {
      _roots = updatedRoots;
      _pathController.clear();
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
      setState(() {
        _items = result.items;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                  pathController: _pathController,
                  scanning: _scanning,
                  onAddRoot: _addRoot,
                  onRemoveRoot: _removeRoot,
                  onScan: _scan,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _MediaShelf(
                  items: _items,
                  skippedPaths: _skippedPaths,
                  error: _error,
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
    required this.pathController,
    required this.scanning,
    required this.onAddRoot,
    required this.onRemoveRoot,
    required this.onScan,
  });

  final List<String> roots;
  final TextEditingController pathController;
  final bool scanning;
  final VoidCallback onAddRoot;
  final ValueChanged<String> onRemoveRoot;
  final VoidCallback onScan;

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
        TextField(
          controller: pathController,
          decoration: const InputDecoration(
            labelText: '媒体目录路径',
            hintText: r'D:\Movies',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          onSubmitted: (_) => onAddRoot(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAddRoot,
                icon: const Icon(Icons.add),
                label: const Text('添加目录'),
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
        const SizedBox(height: 24),
        Text(
          '媒体库目录',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: roots.isEmpty
              ? const _EmptyState(
                  icon: Icons.folder_open,
                  title: '尚未添加目录',
                  message: '输入本地影视文件夹路径后开始扫描。',
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
    required this.skippedPaths,
    required this.error,
  });

  final List<MediaItem> items;
  final List<String> skippedPaths;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatsBar(items: items),
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
        Text(
          '最近添加',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: items.isEmpty
              ? const _EmptyState(
                  icon: Icons.movie_filter_outlined,
                  title: '还没有影片',
                  message: '添加目录并扫描后，这里会显示本地视频文件。',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.maxWidth / 220)
                        .floor()
                        .clamp(2, 6)
                        .toInt();
                    return GridView.builder(
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, index) {
                        return _MediaCard(item: items[index]);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final totalSize = items.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    return Row(
      children: [
        _StatCard(label: '影片', value: '${items.length}'),
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
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.extension.toUpperCase()}  ${_formatDate(item.addedAt)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
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

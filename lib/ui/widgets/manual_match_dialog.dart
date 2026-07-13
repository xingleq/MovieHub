import 'package:flutter/material.dart';

import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_tokens.dart';
import 'cached_tmdb_image.dart';
import 'poster_placeholder.dart';

/// Manual TMDB match dialog (todo §9 手动搜索/修改匹配): search by any
/// keyword and pick the right candidate. Pops the chosen [TmdbMovieMatch].
class ManualMatchDialog extends StatefulWidget {
  const ManualMatchDialog({
    super.key,
    required this.initialQuery,
    required this.onSearch,
  });

  final String initialQuery;
  final Future<List<TmdbMovieMatch>> Function(String query) onSearch;

  @override
  State<ManualMatchDialog> createState() => _ManualMatchDialogState();
}

class _ManualMatchDialogState extends State<ManualMatchDialog> {
  late final TextEditingController _queryController;
  var _loading = false;
  var _results = <TmdbMovieMatch>[];

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
    });
    final results = await widget.onSearch(query);
    if (!mounted) {
      return;
    }
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '手动匹配',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '搜索正确的片名，点选一个结果应用到整部影片/剧集。',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      autofocus: true,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: '片名关键词',
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: _loading ? null : _search,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('搜索'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                    ? Center(
                        child: Text(
                          '没有找到结果，换个关键词试试。',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final match = _results[index];
                          return _CandidateTile(
                            match: match,
                            onTap: () => Navigator.of(context).pop(match),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.match, required this.onTap});

  final TmdbMovieMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final year = (match.releaseDate ?? '').length >= 4
        ? match.releaseDate!.substring(0, 4)
        : null;

    return Material(
      color: tokens.surfaceVariant.withValues(alpha: 0.6),
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.sm),
                ),
                child: SizedBox(
                  width: 56,
                  height: 84,
                  child:
                      match.posterPath != null && match.posterPath!.isNotEmpty
                      ? CachedTmdbImage(
                          url: TmdbClient.posterUrl(match.posterPath!),
                          cacheWidth: 200,
                          placeholderIconSize: 20,
                        )
                      : const PosterPlaceholder(iconSize: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        ?year,
                        match.mediaType == 'tv' ? '剧集' : '电影',
                        if (match.voteAverage > 0)
                          '★ ${match.voteAverage.toStringAsFixed(1)}',
                      ].join(' · '),
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (match.overview.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        match.overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

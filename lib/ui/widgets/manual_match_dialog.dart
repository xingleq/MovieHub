import 'package:flutter/material.dart';

import '../../core/tmdb/tmdb_client.dart';
import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import 'block_asset.dart';
import 'cached_tmdb_image.dart';
import 'poster_placeholder.dart';

class ManualMatchResult {
  const ManualMatchResult({
    required this.match,
    this.seasonNumber,
    this.episodeNumber,
  });

  final TmdbMovieMatch match;
  final int? seasonNumber;
  final int? episodeNumber;
}

/// Manual TMDB match dialog (todo §9 手动搜索/修改匹配): search by any
/// keyword and pick the right candidate. Pops the chosen [TmdbMovieMatch].
class ManualMatchDialog extends StatefulWidget {
  const ManualMatchDialog({
    super.key,
    required this.initialQuery,
    required this.onSearch,
    this.onFetchSeasons,
    this.onFetchEpisodes,
    this.allowEpisodeSelection = false,
  });

  final String initialQuery;
  final Future<List<TmdbMovieMatch>> Function(String query) onSearch;
  final Future<List<TmdbSeasonInfo>> Function(TmdbMovieMatch match)?
  onFetchSeasons;
  final Future<List<TmdbEpisodeInfo>> Function(
    TmdbMovieMatch match,
    int seasonNumber,
  )?
  onFetchEpisodes;
  final bool allowEpisodeSelection;

  @override
  State<ManualMatchDialog> createState() => _ManualMatchDialogState();
}

class _ManualMatchDialogState extends State<ManualMatchDialog> {
  late final TextEditingController _queryController;
  late final TextEditingController _seasonController;
  late final TextEditingController _episodeController;
  var _loading = false;
  var _episodeLoading = false;
  var _results = <TmdbMovieMatch>[];
  TmdbMovieMatch? _selectedTv;
  var _seasons = <TmdbSeasonInfo>[];
  var _episodes = <TmdbEpisodeInfo>[];
  int? _selectedSeason;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    final parsed = _parseSeasonEpisode(widget.initialQuery);
    _seasonController = TextEditingController(
      text: parsed?.$1.toString() ?? '',
    );
    _episodeController = TextEditingController(
      text: parsed?.$2.toString() ?? '',
    );
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _seasonController.dispose();
    _episodeController.dispose();
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

  Future<void> _selectMatch(TmdbMovieMatch match) async {
    if (!widget.allowEpisodeSelection || match.mediaType != 'tv') {
      Navigator.of(context).pop(ManualMatchResult(match: match));
      return;
    }

    setState(() {
      _selectedTv = match;
      _episodeLoading = true;
      _seasons = [];
      _episodes = [];
      _selectedSeason = null;
    });

    final seasons = await widget.onFetchSeasons?.call(match) ?? const [];
    if (!mounted) {
      return;
    }
    final parsedSeason = int.tryParse(_seasonController.text.trim());
    final selectedSeason =
        seasons.any((season) => season.seasonNumber == parsedSeason)
        ? parsedSeason
        : seasons.isNotEmpty
        ? seasons.first.seasonNumber
        : null;
    setState(() {
      _seasons = seasons;
      _selectedSeason = selectedSeason;
    });
    if (selectedSeason != null) {
      await _loadEpisodes(selectedSeason);
    } else {
      setState(() {
        _episodeLoading = false;
      });
    }
  }

  Future<void> _loadEpisodes(int seasonNumber) async {
    final selectedTv = _selectedTv;
    if (selectedTv == null) {
      return;
    }
    setState(() {
      _episodeLoading = true;
      _selectedSeason = seasonNumber;
      _seasonController.text = seasonNumber.toString();
      _episodes = [];
    });

    final episodes =
        await widget.onFetchEpisodes?.call(selectedTv, seasonNumber) ??
        const [];
    if (!mounted) {
      return;
    }
    setState(() {
      _episodes = episodes;
      _episodeLoading = false;
    });
  }

  void _applySelected({TmdbEpisodeInfo? episode}) {
    final match = _selectedTv;
    if (match == null) {
      return;
    }
    final seasonNumber =
        episode?.seasonNumber ?? int.tryParse(_seasonController.text.trim());
    final episodeNumber =
        episode?.episodeNumber ?? int.tryParse(_episodeController.text.trim());
    Navigator.of(context).pop(
      ManualMatchResult(
        match: match,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    final selectedTv = _selectedTv;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
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
                selectedTv == null
                    ? '搜索正确的片名；单集视频可继续选择季和集。'
                    : '选择季和集，或手动输入季/集后保存。',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (selectedTv == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        autofocus: true,
                        onSubmitted: (_) => _search(),
                        decoration: const InputDecoration(
                          hintText: '片名关键词，例如 数码宝贝 第一季 第2集',
                          isDense: true,
                          prefixIcon: BlockIcon(AppAssets.search, size: 20),
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
                              onTap: () => _selectMatch(match),
                            );
                          },
                        ),
                ),
              ] else
                Expanded(child: _episodePicker()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _episodePicker() {
    final tokens = AppTokens.of(context);
    final selectedTv = _selectedTv!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CandidateTile(match: selectedTv, onTap: () {}),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _seasonController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '季',
                  isDense: true,
                  prefixIcon: Icon(Icons.layers_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: _episodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '集',
                  isDense: true,
                  prefixIcon: Icon(Icons.playlist_play, size: 20),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton(onPressed: _applySelected, child: const Text('保存季集')),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_seasons.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _seasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final season = _seasons[index];
                final selected = season.seasonNumber == _selectedSeason;
                return ChoiceChip(
                  selected: selected,
                  label: Text(
                    'S${season.seasonNumber.toString().padLeft(2, '0')}'
                    ' · ${season.episodeCount}集',
                  ),
                  onSelected: (_) => _loadEpisodes(season.seasonNumber),
                );
              },
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _episodeLoading
              ? const Center(child: CircularProgressIndicator())
              : _episodes.isEmpty
              ? Center(
                  child: Text(
                    '没有读取到分集，可直接手动输入季/集。',
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: _episodes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final episode = _episodes[index];
                    return Material(
                      color: tokens.surfaceVariant.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadius.md),
                      ),
                      child: ListTile(
                        title: Text(
                          'E${episode.episodeNumber.toString().padLeft(2, '0')}'
                          '  ${episode.name.isEmpty ? '第 ${episode.episodeNumber} 集' : episode.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: episode.overview.isEmpty
                            ? null
                            : Text(
                                episode.overview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => _applySelected(episode: episode),
                      ),
                    );
                  },
                ),
        ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedTv = null;
              _episodes = [];
              _seasons = [];
            });
          },
          icon: const BlockIcon(AppAssets.back, size: 22),
          label: const Text('返回搜索结果'),
        ),
      ],
    );
  }

  static (int, int)? _parseSeasonEpisode(String query) {
    final patterns = [
      RegExp(r'S(\d{1,2})E(\d{1,3})', caseSensitive: false),
      RegExp(r'第\s*(\d{1,2})\s*季.*第\s*(\d{1,3})\s*[集话話]'),
      RegExp(r'(\d{1,2})\s*[季部].*(\d{1,3})\s*[集话話]'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match == null) {
        continue;
      }
      final season = int.tryParse(match.group(1)!);
      final episode = int.tryParse(match.group(2)!);
      if (season != null && episode != null) {
        return (season, episode);
      }
    }
    return null;
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

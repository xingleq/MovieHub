import 'media_item.dart';

/// A wall entry: one movie, or one series aggregating all its episodes.
/// Grouping is a pure domain concept — persistence stays per-file.
class MediaGroup {
  MediaGroup({required this.key, required this.episodes})
    : assert(episodes.isNotEmpty, 'a group needs at least one item');

  final String key;

  /// Sorted by season then episode; a single element for movies.
  final List<MediaItem> episodes;

  bool get isSeries => episodes.length > 1 || episodes.first.isEpisode;

  /// The item whose artwork/metadata represents the group (prefers a matched
  /// one with a poster).
  MediaItem get representative {
    for (final episode in episodes) {
      if ((episode.posterPath ?? '').isNotEmpty) {
        return episode;
      }
    }
    return episodes.first;
  }

  String get title {
    final rep = representative;
    if (isSeries) {
      return rep.tmdbTitle ?? rep.seriesTitle ?? rep.title;
    }
    return rep.tmdbTitle ?? rep.title;
  }

  int get watchedCount {
    return episodes.where((episode) => episode.playbackProgress >= 0.95).length;
  }

  bool get allWatched => watchedCount == episodes.length;

  /// First episode not finished yet, in season/episode order.
  MediaItem? get nextUnwatched {
    for (final episode in episodes) {
      if (episode.playbackProgress < 0.95) {
        return episode;
      }
    }
    return null;
  }

  /// What the play button starts: the next unwatched episode, or a rewatch
  /// from the first one.
  MediaItem get playTarget => nextUnwatched ?? episodes.first;

  DateTime get addedAt {
    var latest = episodes.first.addedAt;
    for (final episode in episodes.skip(1)) {
      if (episode.addedAt.isAfter(latest)) {
        latest = episode.addedAt;
      }
    }
    return latest;
  }

  bool get anyFavorite => episodes.any((episode) => episode.favorite);

  List<String> get paths =>
      episodes.map((episode) => episode.path).toList(growable: false);

  /// Group key for an episode: episodes matched to the same TMDB series
  /// merge even when their parsed filenames differ; unmatched ones fall
  /// back to the parsed series title.
  static String keyOf(MediaItem item) {
    final tmdbId = item.tmdbId;
    if (item.tmdbMediaType == 'tv' && tmdbId != null) {
      return 'series:tmdb:$tmdbId';
    }
    return titleKeyOf(item);
  }

  /// Title-based key, ignoring any TMDB match. Used to re-resolve a stale
  /// navigation key after a match changed a group's [keyOf].
  static String titleKeyOf(MediaItem item) {
    return 'series:${(item.seriesTitle ?? item.title).toLowerCase()}';
  }
}

/// Groups episodes of the same series into one [MediaGroup]; everything
/// else becomes a single-item group.
///
/// Two passes: episodes bucket by parsed title first, then buckets whose
/// members carry a TMDB series id re-key to `series:tmdb:<id>`. That merges
/// differently-named folders of the same series and keeps not-yet-matched
/// episodes together with their matched siblings.
List<MediaGroup> groupMediaItems(Iterable<MediaItem> items) {
  final titleBuckets = <String, List<MediaItem>>{};
  final singles = <MediaGroup>[];

  for (final item in items) {
    final seriesTitle = item.seriesTitle;
    if (item.isEpisode && seriesTitle != null && seriesTitle.isNotEmpty) {
      titleBuckets.putIfAbsent(MediaGroup.titleKeyOf(item), () => []).add(item);
    } else {
      singles.add(MediaGroup(key: item.path, episodes: [item]));
    }
  }

  final merged = <String, List<MediaItem>>{};
  for (final bucket in titleBuckets.values) {
    final keyed = bucket.firstWhere(
      (item) => item.tmdbMediaType == 'tv' && item.tmdbId != null,
      orElse: () => bucket.first,
    );
    merged.putIfAbsent(MediaGroup.keyOf(keyed), () => []).addAll(bucket);
  }

  return [
    ...singles,
    for (final entry in merged.entries)
      MediaGroup(key: entry.key, episodes: entry.value..sort(compareEpisodes)),
  ];
}

int compareEpisodes(MediaItem a, MediaItem b) {
  final bySeason = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
  if (bySeason != 0) {
    return bySeason;
  }
  return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
}

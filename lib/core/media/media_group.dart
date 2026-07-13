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

  /// Stable group key for a series title, shared with detail navigation.
  static String seriesKey(String seriesTitle) {
    return 'series:${seriesTitle.toLowerCase()}';
  }
}

/// Groups episodes of the same series (by parsed series title) into one
/// [MediaGroup]; everything else becomes a single-item group.
List<MediaGroup> groupMediaItems(Iterable<MediaItem> items) {
  final seriesBuckets = <String, List<MediaItem>>{};
  final singles = <MediaGroup>[];

  for (final item in items) {
    final seriesTitle = item.seriesTitle;
    if (item.isEpisode && seriesTitle != null && seriesTitle.isNotEmpty) {
      seriesBuckets.putIfAbsent(seriesTitle.toLowerCase(), () => []).add(item);
    } else {
      singles.add(MediaGroup(key: item.path, episodes: [item]));
    }
  }

  return [
    ...singles,
    for (final entry in seriesBuckets.entries)
      MediaGroup(
        key: 'series:${entry.key}',
        episodes: entry.value..sort(compareEpisodes),
      ),
  ];
}

int compareEpisodes(MediaItem a, MediaItem b) {
  final bySeason = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
  if (bySeason != 0) {
    return bySeason;
  }
  return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
}

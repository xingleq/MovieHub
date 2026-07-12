import '../../core/media/media_item.dart';

/// Sort orders for the poster-wall catalog pages (todo §16).
enum SortKey {
  addedAt('添加时间'),
  title('片名'),
  year('年份'),
  rating('评分');

  const SortKey(this.label);

  final String label;
}

/// Poster density for the catalog grid (todo §16 大海报/小海报).
enum PosterSize {
  large('大'),
  small('小');

  const PosterSize(this.label);

  final String label;

  double get targetCardWidth {
    return this == PosterSize.large ? 200 : 152;
  }
}

/// Returns a new list sorted by [key], descending for time/year/rating and
/// ascending for titles.
List<MediaItem> sortItems(List<MediaItem> items, SortKey key) {
  final sorted = [...items];
  switch (key) {
    case SortKey.addedAt:
      sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    case SortKey.title:
      sorted.sort((a, b) {
        return _displayTitle(a).compareTo(_displayTitle(b));
      });
    case SortKey.year:
      sorted.sort((a, b) => _year(b).compareTo(_year(a)));
    case SortKey.rating:
      sorted.sort((a, b) {
        return (b.voteAverage ?? -1).compareTo(a.voteAverage ?? -1);
      });
  }
  return sorted;
}

String _displayTitle(MediaItem item) {
  return (item.tmdbTitle ?? item.title).toLowerCase();
}

int _year(MediaItem item) {
  final releaseDate = item.releaseDate;
  if (releaseDate == null || releaseDate.length < 4) {
    return 0;
  }
  return int.tryParse(releaseDate.substring(0, 4)) ?? 0;
}

/// Extracts a display year from an item's release date, or null.
String? releaseYear(MediaItem item) {
  final year = _year(item);
  return year == 0 ? null : '$year';
}

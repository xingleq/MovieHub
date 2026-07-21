import '../../core/media/media_group.dart';
import '../../core/media/media_item.dart';

/// TMDB genre id for Animation (both movie and TV).
const _animationGenreId = 16;
// same way now that genre ids are scraped — add when the library carries them.

/// Anime/animation: TMDB genre 16. Unmatched items can't be classified yet,
/// so they stay in 电影/电视剧 until scraped.
bool isAnime(MediaItem item) {
  return item.genreIds?.contains(_animationGenreId) ?? false;
}

/// An item counts as TV when TMDB says so, or when the filename parsed to a
/// season/episode pattern before any scraping happened. Animation is split
/// out into its own section, kid-first.
bool isTv(MediaItem item) {
  return item.tmdbMediaType == 'tv' || item.isEpisode;
}

bool isMovie(MediaItem item) {
  return !isTv(item);
}

/// Rail-section predicates: 动画 owns everything animated; 电影/电视剧 exclude
/// it so the three sections stay disjoint.
bool isAnimeSection(MediaItem item) => isAnime(item);

bool isMovieSection(MediaItem item) => isMovie(item) && !isAnime(item);

bool isTvSection(MediaItem item) => isTv(item) && !isAnime(item);

/// Group-level section predicates for the poster walls.
bool isAnimeGroup(MediaGroup group) => isAnime(group.representative);

bool isMovieGroup(MediaGroup group) {
  return !isAnimeGroup(group) &&
      !group.isSeries &&
      isMovie(group.representative);
}

bool isTvGroup(MediaGroup group) {
  return !isAnimeGroup(group) && (group.isSeries || isTv(group.representative));
}

bool isFavoriteGroup(MediaGroup group) => group.anyFavorite;

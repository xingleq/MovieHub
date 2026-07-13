/// Filename → title/episode parsing, extracted from the scan path so
/// [MediaItem] stays a plain data record and the rules are unit-testable.
library;

class ParsedFileName {
  const ParsedFileName({
    required this.title,
    this.seriesTitle,
    this.seasonNumber,
    this.episodeNumber,
  });

  /// Display title: the cleaned filename, or `Series S01E02` for episodes.
  final String title;
  final String? seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;
}

/// Parses a video file name (without extension) into a display title and,
/// when a `S01E02` / `1x02` pattern is present, series/season/episode parts.
ParsedFileName parseFileName(String rawTitle) {
  final episodeInfo = _parseEpisodeInfo(rawTitle);
  if (episodeInfo == null) {
    return ParsedFileName(title: cleanTitle(rawTitle));
  }
  return ParsedFileName(
    title:
        '${episodeInfo.seriesTitle} '
        'S${twoDigits(episodeInfo.seasonNumber)}'
        'E${twoDigits(episodeInfo.episodeNumber)}',
    seriesTitle: episodeInfo.seriesTitle,
    seasonNumber: episodeInfo.seasonNumber,
    episodeNumber: episodeInfo.episodeNumber,
  );
}

/// Replaces dot/underscore separators with spaces and collapses whitespace.
String cleanTitle(String rawTitle) {
  final cleaned = rawTitle
      .replaceAll(RegExp(r'[._]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? rawTitle : cleaned;
}

String twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

_EpisodeInfo? _parseEpisodeInfo(String rawTitle) {
  final normalized = rawTitle.replaceAll(RegExp(r'[._]+'), ' ');
  final patterns = [
    RegExp(r'\bS(\d{1,2})E(\d{1,3})\b', caseSensitive: false),
    RegExp(r'\b(\d{1,2})x(\d{1,3})\b', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(normalized);
    if (match == null) {
      continue;
    }

    final season = int.tryParse(match.group(1)!);
    final episode = int.tryParse(match.group(2)!);
    if (season == null || episode == null) {
      continue;
    }

    final titlePart = normalized.substring(0, match.start);
    final seriesTitle = cleanTitle(titlePart);
    if (seriesTitle.isEmpty) {
      continue;
    }

    return _EpisodeInfo(
      seriesTitle: seriesTitle,
      seasonNumber: season,
      episodeNumber: episode,
    );
  }

  return null;
}

class _EpisodeInfo {
  const _EpisodeInfo({
    required this.seriesTitle,
    required this.seasonNumber,
    required this.episodeNumber,
  });

  final String seriesTitle;
  final int seasonNumber;
  final int episodeNumber;
}

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

/// An episode number recognized inside a file name.
class EpisodeNumber {
  const EpisodeNumber({required this.value, required this.explicit});

  final int value;

  /// True for unambiguous markers (第x集/话, EP01). A bare leading number
  /// (01大冒险) is not explicit — the scanner requires directory evidence
  /// (a season folder or several numbered siblings) before trusting it,
  /// so films like `007.mkv` or `2001太空漫游.mkv` stay movies.
  final bool explicit;
}

/// Series title and season parsed from a directory name, e.g.
/// `数码宝贝第一季` → (数码宝贝, 1), `Yes Minister Season 2` → (Yes Minister, 2),
/// `第一季` → ('', 1), `经典电影` → (经典电影, null).
class DirectoryInfo {
  const DirectoryInfo({required this.seriesTitle, this.seasonNumber});

  final String seriesTitle;
  final int? seasonNumber;

  /// A folder that is nothing but a season marker (第一季 / Season 1 / S01);
  /// the series name then lives one level up.
  bool get isPureSeason => seriesTitle.isEmpty && seasonNumber != null;
}

final _explicitEpisodePatterns = [
  RegExp(r'第\s*([0-9一二三四五六七八九十]{1,6})\s*[集话話回]'),
  RegExp(
    r'(?:^|[\s._\-\[（(【])(?:EP|E)\s*(\d{1,4})(?!\d)',
    caseSensitive: false,
  ),
];

final _leadingEpisodeNumberPattern = RegExp(r'^[\s\[（(【]*(\d{1,3})(?!\d)');

/// Finds an episode number in a file name (without extension): an explicit
/// `第01集/话/回` or `EP01`/`E01` marker, else a bare leading number
/// (`01大冒险`). Returns null when neither is present.
EpisodeNumber? parseEpisodeNumber(String rawTitle) {
  for (final pattern in _explicitEpisodePatterns) {
    final match = pattern.firstMatch(rawTitle);
    if (match == null) {
      continue;
    }
    final value = _numberOf(match.group(1)!);
    if (value != null) {
      return EpisodeNumber(value: value, explicit: true);
    }
  }

  final leading = _leadingEpisodeNumberPattern.firstMatch(rawTitle);
  if (leading != null) {
    final value = int.tryParse(leading.group(1)!);
    if (value != null) {
      return EpisodeNumber(value: value, explicit: false);
    }
  }
  return null;
}

final _seasonMarkerPatterns = [
  RegExp(r'第\s*([0-9一二三四五六七八九十]{1,6})\s*[季部]'),
  RegExp(r'season\s*(\d{1,2})', caseSensitive: false),
  RegExp(r'(?:^|[\s._-])S(\d{1,2})(?:$|[\s._-])', caseSensitive: false),
];

/// Splits a directory name into a series title and an optional season
/// number. The season marker is removed from the title; a name that is
/// only a marker yields an empty title ([DirectoryInfo.isPureSeason]).
DirectoryInfo parseDirectoryName(String directoryName) {
  for (final pattern in _seasonMarkerPatterns) {
    final match = pattern.firstMatch(directoryName);
    if (match == null) {
      continue;
    }
    final season = _numberOf(match.group(1)!);
    if (season == null) {
      continue;
    }
    final stripped = directoryName
        .replaceRange(match.start, match.end, ' ')
        .trim();
    return DirectoryInfo(
      seriesTitle: stripped.isEmpty ? '' : cleanTitle(stripped),
      seasonNumber: season,
    );
  }
  return DirectoryInfo(seriesTitle: cleanTitle(directoryName));
}

/// Parses ASCII digits or simple Chinese numerals (一 ~ 九十九).
int? _numberOf(String raw) {
  final arabic = int.tryParse(raw);
  if (arabic != null) {
    return arabic;
  }

  const digits = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  final tenIndex = raw.indexOf('十');
  if (tenIndex < 0) {
    return raw.length == 1 ? digits[raw] : null;
  }
  final tensPart = raw.substring(0, tenIndex);
  final onesPart = raw.substring(tenIndex + 1);
  final tens = tensPart.isEmpty ? 1 : digits[tensPart];
  final ones = onesPart.isEmpty ? 0 : digits[onesPart];
  if (tens == null || ones == null) {
    return null;
  }
  return tens * 10 + ones;
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

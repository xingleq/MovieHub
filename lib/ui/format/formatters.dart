/// Formats a [Duration] as `H:MM:SS` (or `MM:SS` when under an hour).
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

/// Formats a byte count into a human-readable size (B / KB / MB / GB).
String formatBytes(int bytes) {
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

/// Formats a [DateTime] as `YYYY-MM-DD` in local time.
String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

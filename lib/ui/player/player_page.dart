import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/settings_controller.dart';
import '../../core/media/media_item.dart';
import '../../core/system/session_events.dart';
import '../../theme/app_tokens.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.item,
    required this.onProgressChanged,
    this.startAt,
    this.previousEpisodeOf,
    this.nextEpisodeOf,
    this.onClose,
    this.onCompactChanged,
    this.subtitlePreference = 'zh-hans',
    this.audioPreference = 'zh',
    required this.settings,
  });

  final MediaItem item;

  /// Position to start playback from; null plays from the beginning. Passed
  /// to [Media.start] so libmpv opens directly at the offset — seeking right
  /// after [Player.open] races media loading and gets silently dropped.
  final Duration? startAt;

  /// Looks up the following episode of a series item; enables the next
  /// button and auto-play-next on completion (todo §15).
  final MediaItem? Function(MediaItem item)? previousEpisodeOf;
  final MediaItem? Function(MediaItem item)? nextEpisodeOf;

  final VoidCallback? onClose;
  final ValueChanged<bool>? onCompactChanged;

  /// Default subtitle preference: 'zh-hans' | 'zh-hant' | 'en' | 'off'.
  final String subtitlePreference;

  /// Default audio preference: 'zh' | 'ja' | 'en'.
  final String audioPreference;

  final SettingsController settings;

  final Future<void> Function(
    MediaItem item,
    Duration position,
    Duration duration,
  )
  onProgressChanged;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _durationSubscription;
  late final StreamSubscription<Tracks> _tracksSubscription;
  late final StreamSubscription<bool> _playingSubscription;
  late final StreamSubscription<bool> _completedSubscription;
  late final StreamSubscription<String> _sessionSubscription;
  late final Timer _progressSaveTimer;

  late MediaItem _currentItem;
  var _lastPosition = Duration.zero;
  var _lastDuration = Duration.zero;
  String? _autoTracksAppliedFor;
  var _switchingEpisode = false;
  var _compact = false;
  var _hasStartedPlaying = false;

  /// Progress is also checkpointed while playing (a crash or force-close
  /// otherwise loses the whole session); each save writes a single row.
  static const _progressSaveInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _player = Player();
    _controller = VideoController(_player);
    _positionSubscription = _player.stream.position.listen((position) {
      _lastPosition = position;
    });
    _durationSubscription = _player.stream.duration.listen((duration) {
      _lastDuration = duration;
    });
    _tracksSubscription = _player.stream.tracks.listen(_applyPreferredTracks);
    _playingSubscription = _player.stream.playing.listen((playing) {
      if (playing) {
        _hasStartedPlaying = true;
      }
      final compact = _hasStartedPlaying && !playing;
      if (_compact == compact) {
        return;
      }
      setState(() {
        _compact = compact;
      });
      widget.onCompactChanged?.call(compact);
    });
    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed) {
        unawaited(_autoPlayNext());
      }
    });
    // Pause when the workstation locks; resuming stays a manual action.
    _sessionSubscription = SessionEvents.stream.listen((event) {
      if (event == 'lock' && _player.state.playing) {
        unawaited(_player.pause());
      }
    });
    widget.settings.addListener(_pauseForBreakIfNeeded);
    _progressSaveTimer = Timer.periodic(_progressSaveInterval, (_) {
      if (_player.state.playing && _lastDuration.inMilliseconds > 0) {
        unawaited(
          widget.onProgressChanged(_currentItem, _lastPosition, _lastDuration),
        );
      }
    });
    unawaited(_player.open(Media(_currentItem.path, start: widget.startAt)));
  }

  @override
  void dispose() {
    _progressSaveTimer.cancel();
    unawaited(_positionSubscription.cancel());
    unawaited(_durationSubscription.cancel());
    unawaited(_tracksSubscription.cancel());
    unawaited(_playingSubscription.cancel());
    unawaited(_completedSubscription.cancel());
    unawaited(_sessionSubscription.cancel());
    widget.settings.removeListener(_pauseForBreakIfNeeded);
    unawaited(
      widget.onProgressChanged(_currentItem, _lastPosition, _lastDuration),
    );
    _player.dispose();
    super.dispose();
  }

  void _pauseForBreakIfNeeded() {
    if (widget.settings.breakActive && _player.state.playing) {
      unawaited(_player.pause());
    }
  }

  /// Named preference tiers; the user's configured preference is moved to
  /// the front, the rest keep the todo §12/§13 default order.
  static const _subtitleTiers = <String, (Set<String>, List<String>)>{
    'zh-hans': ({'zh-hans', 'chs'}, ['简体', '简中', 'simplified']),
    'zh-hant': ({'zh-hant', 'cht'}, ['繁体', '繁中', 'traditional']),
    'zh': ({'zh', 'chi', 'zho'}, ['中文', 'chinese', '中字']),
    'en': ({'en', 'eng'}, ['english', '英文', '英语']),
  };

  static const _audioTiers = <String, (Set<String>, List<String>)>{
    'zh': (
      {'zh', 'chi', 'zho', 'zh-hans', 'zh-hant', 'chs', 'cht'},
      ['中文', '国语', '普通话', 'mandarin', 'chinese'],
    ),
    'ja': ({'ja', 'jpn', 'jp'}, ['日语', 'japanese', '日本語']),
    'en': ({'en', 'eng'}, ['english', '英语']),
  };

  static List<(Set<String>, List<String>)> _orderedTiers(
    Map<String, (Set<String>, List<String>)> tiers,
    String preference,
  ) {
    return [
      if (tiers.containsKey(preference)) tiers[preference]!,
      for (final entry in tiers.entries)
        if (entry.key != preference) entry.value,
    ];
  }

  /// Auto-selects the default subtitle and audio tracks per the configured
  /// preferences (todo §12/§13) once per opened media.
  void _applyPreferredTracks(Tracks tracks) {
    if (_autoTracksAppliedFor == _currentItem.path) {
      return;
    }

    final subtitles = tracks.subtitle
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();
    final audios = tracks.audio
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();
    if (subtitles.isEmpty && audios.isEmpty) {
      return;
    }
    _autoTracksAppliedFor = _currentItem.path;

    if (widget.subtitlePreference == 'off') {
      unawaited(_player.setSubtitleTrack(SubtitleTrack.no()));
    } else {
      final subtitle = _pickByPreference(
        subtitles,
        (track) => (track.language, track.title),
        _orderedTiers(_subtitleTiers, widget.subtitlePreference),
      );
      if (subtitle != null) {
        unawaited(_player.setSubtitleTrack(subtitle));
      }
    }

    final audio = _pickByPreference(
      audios,
      (track) => (track.language, track.title),
      _orderedTiers(_audioTiers, widget.audioPreference),
    );
    if (audio != null) {
      unawaited(_player.setAudioTrack(audio));
    }
  }

  /// Returns the first track matching the ordered preference tiers (language
  /// code exact/prefix match, or title keyword). Falls back to the first
  /// track — todo §12/§13 "其它/第一条".
  static T? _pickByPreference<T>(
    List<T> tracks,
    (String?, String?) Function(T track) accessor,
    List<(Set<String>, List<String>)> tiers,
  ) {
    for (final (codes, titleKeys) in tiers) {
      for (final track in tracks) {
        final (language, title) = accessor(track);
        final lang = (language ?? '').toLowerCase();
        final name = (title ?? '').toLowerCase();
        if (codes.contains(lang) ||
            codes.any((code) => lang.startsWith('$code-')) ||
            titleKeys.any(name.contains)) {
          return track;
        }
      }
    }
    return tracks.isEmpty ? null : tracks.first;
  }

  MediaItem? get _nextEpisode {
    return widget.nextEpisodeOf?.call(_currentItem);
  }

  MediaItem? get _previousEpisode {
    return widget.previousEpisodeOf?.call(_currentItem);
  }

  /// On natural completion: mark the finished episode watched, then continue
  /// with the next one.
  Future<void> _autoPlayNext() async {
    if (_switchingEpisode) {
      return;
    }
    final next = _nextEpisode;
    if (next == null) {
      return;
    }
    final finished = _lastDuration;
    if (finished.inMilliseconds > 0) {
      unawaited(widget.onProgressChanged(_currentItem, finished, finished));
    }
    await _switchTo(next);
  }

  /// Manual skip: save the current position as-is, then switch.
  Future<void> _playNextManually() async {
    if (_switchingEpisode) {
      return;
    }
    final next = _nextEpisode;
    if (next == null) {
      return;
    }
    unawaited(
      widget.onProgressChanged(_currentItem, _lastPosition, _lastDuration),
    );
    await _switchTo(next);
  }

  Future<void> _playPreviousManually() async {
    if (_switchingEpisode) {
      return;
    }
    final previous = _previousEpisode;
    if (previous == null) {
      return;
    }
    unawaited(
      widget.onProgressChanged(_currentItem, _lastPosition, _lastDuration),
    );
    await _switchTo(previous);
  }

  Future<void> _switchTo(MediaItem next) async {
    _switchingEpisode = true;
    try {
      setState(() {
        _currentItem = next;
      });
      _autoTracksAppliedFor = null;
      _lastPosition = Duration.zero;
      _lastDuration = Duration.zero;
      _compact = false;
      _hasStartedPlaying = false;
      widget.onCompactChanged?.call(false);

      final resume =
          next.playbackPositionMs > 5000 && next.playbackProgress < 0.95
          ? Duration(milliseconds: next.playbackPositionMs)
          : null;
      await _player.open(Media(next.path, start: resume));
    } finally {
      _switchingEpisode = false;
    }
  }

  Future<void> _takeScreenshot() async {
    final bytes = await _player.screenshot(format: 'image/png');
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (bytes == null) {
      messenger.showSnackBar(const SnackBar(content: Text('截图失败')));
      return;
    }

    try {
      final home = Platform.environment['USERPROFILE'] ?? '';
      final separator = Platform.pathSeparator;
      final directory = Directory(
        '$home${separator}Pictures${separator}MovieHub',
      );
      await directory.create(recursive: true);

      final safeTitle = (_currentItem.tmdbTitle ?? _currentItem.title)
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final now = DateTime.now();
      final stamp =
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final file = File('${directory.path}$separator${safeTitle}_$stamp.png');
      await file.writeAsBytes(bytes);
      messenger.showSnackBar(SnackBar(content: Text('截图已保存：${file.path}')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('截图保存失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    final controlsTheme = MaterialDesktopVideoControlsThemeData(
      seekBarPositionColor: tokens.accent,
      seekBarThumbColor: tokens.accent,
      bottomButtonBar: [
        const MaterialDesktopPlayOrPauseButton(),
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(),
        const Spacer(),
        if (_previousEpisode != null)
          MaterialDesktopCustomButton(
            onPressed: () => unawaited(_playPreviousManually()),
            icon: const Icon(Icons.skip_previous),
          ),
        if (_nextEpisode != null)
          MaterialDesktopCustomButton(
            onPressed: () => unawaited(_playNextManually()),
            icon: const Icon(Icons.skip_next),
          ),
        _RateButton(player: _player),
        _TrackMenuButton(
          tooltip: '字幕',
          icon: Icons.subtitles_outlined,
          loadTracks: () => [
            (SubtitleTrack.no(), '关闭字幕'),
            for (final (index, track)
                in _player.state.tracks.subtitle
                    .where((track) => track.id != 'auto' && track.id != 'no')
                    .indexed)
              (track, _trackLabel(track.title, track.language, index)),
          ],
          isSelected: (track) =>
              _player.state.track.subtitle.id == (track as SubtitleTrack).id,
          onSelected: (track) =>
              unawaited(_player.setSubtitleTrack(track as SubtitleTrack)),
        ),
        _TrackMenuButton(
          tooltip: '音轨',
          icon: Icons.graphic_eq,
          loadTracks: () => [
            for (final (index, track)
                in _player.state.tracks.audio
                    .where((track) => track.id != 'auto' && track.id != 'no')
                    .indexed)
              (track, _trackLabel(track.title, track.language, index)),
          ],
          isSelected: (track) =>
              _player.state.track.audio.id == (track as AudioTrack).id,
          onSelected: (track) =>
              unawaited(_player.setAudioTrack(track as AudioTrack)),
        ),
        MaterialDesktopCustomButton(
          onPressed: () => unawaited(_takeScreenshot()),
          icon: const Icon(Icons.photo_camera_outlined),
        ),
        const MaterialDesktopFullscreenButton(),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: '关闭播放器',
          onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(
          _currentItem.tmdbTitle ?? _currentItem.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: _previousEpisode == null ? '没有上一集' : '上一集',
            onPressed: _previousEpisode == null
                ? null
                : () => unawaited(_playPreviousManually()),
            icon: const Icon(Icons.skip_previous),
          ),
          IconButton(
            tooltip: _nextEpisode == null ? '没有下一集' : '下一集',
            onPressed: _nextEpisode == null
                ? null
                : () => unawaited(_playNextManually()),
            icon: const Icon(Icons.skip_next),
          ),
          if (_compact)
            IconButton(
              tooltip: '恢复播放',
              onPressed: () => unawaited(_player.play()),
              icon: const Icon(Icons.open_in_full),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: MaterialDesktopVideoControlsTheme(
        normal: controlsTheme,
        fullscreen: controlsTheme,
        child: Video(
          controller: _controller,
          controls: MaterialDesktopVideoControls,
        ),
      ),
    );
  }

  static String _trackLabel(String? title, String? language, int index) {
    final parts = [
      if (title != null && title.trim().isNotEmpty) title.trim(),
      if (language != null && language.trim().isNotEmpty) language.trim(),
    ];
    if (parts.isEmpty) {
      return '轨道 ${index + 1}';
    }
    return parts.join(' · ');
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({required this.player});

  final Player player;

  static const _rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: '倍速',
      initialValue: player.state.rate,
      onSelected: (rate) => player.setRate(rate),
      color: const Color(0xE6202124),
      itemBuilder: (context) => [
        for (final rate in _rates)
          PopupMenuItem(
            value: rate,
            child: Text(
              rate == 1.0 ? '正常速度' : '${rate}x',
              style: const TextStyle(color: Colors.white),
            ),
          ),
      ],
      icon: const Icon(Icons.speed, color: Colors.white),
    );
  }
}

/// Popup menu listing tracks read lazily at open time, so no stream wiring
/// is needed.
class _TrackMenuButton extends StatelessWidget {
  const _TrackMenuButton({
    required this.tooltip,
    required this.icon,
    required this.loadTracks,
    required this.isSelected,
    required this.onSelected,
  });

  final String tooltip;
  final IconData icon;
  final List<(Object, String)> Function() loadTracks;
  final bool Function(Object track) isSelected;
  final ValueChanged<Object> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      tooltip: tooltip,
      onSelected: onSelected,
      color: const Color(0xE6202124),
      itemBuilder: (context) {
        final entries = loadTracks();
        if (entries.isEmpty) {
          return const [
            PopupMenuItem<Object>(
              enabled: false,
              child: Text('无可用轨道', style: TextStyle(color: Colors.white70)),
            ),
          ];
        }
        return [
          for (final (track, label) in entries)
            CheckedPopupMenuItem<Object>(
              value: track,
              checked: isSelected(track),
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
        ];
      },
      icon: Icon(icon, color: Colors.white),
    );
  }
}

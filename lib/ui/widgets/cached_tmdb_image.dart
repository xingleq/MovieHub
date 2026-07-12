import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/images/image_cache_store.dart';
import 'poster_placeholder.dart';

/// Renders a TMDB image from the local disk cache, downloading it on first
/// use. Shows the shared placeholder while loading or on failure.
class CachedTmdbImage extends StatefulWidget {
  const CachedTmdbImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.placeholderIconSize = 40,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final double placeholderIconSize;

  @override
  State<CachedTmdbImage> createState() => _CachedTmdbImageState();
}

class _CachedTmdbImageState extends State<CachedTmdbImage> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachedTmdbImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _file = null;
      _load();
    }
  }

  void _load() {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      return;
    }

    final cached = ImageCacheStore.instance.cachedFileSync(url);
    if (cached != null) {
      _file = cached;
      return;
    }

    ImageCacheStore.instance.resolve(url).then((file) {
      if (!mounted || file == null || widget.url != url) {
        return;
      }
      setState(() {
        _file = file;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) {
      return PosterPlaceholder(iconSize: widget.placeholderIconSize);
    }
    return Image.file(
      file,
      fit: widget.fit,
      alignment: widget.alignment,
      cacheWidth: widget.cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          PosterPlaceholder(iconSize: widget.placeholderIconSize),
    );
  }
}

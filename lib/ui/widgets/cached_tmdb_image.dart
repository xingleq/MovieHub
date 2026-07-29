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
    this.placeholder,
    this.retainPreviousImage = false,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final double placeholderIconSize;
  final Widget? placeholder;

  /// Keeps the currently displayed file visible while a replacement URL is
  /// resolved. This avoids a flash of placeholder when switching backdrops.
  final bool retainPreviousImage;

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
      if (!widget.retainPreviousImage ||
          widget.url == null ||
          widget.url!.isEmpty) {
        _file = null;
      }
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
      if (!mounted || widget.url != url) {
        return;
      }
      setState(() {
        // A failed replacement must clear a retained previous image; showing
        // artwork from another title is more misleading than the fallback.
        _file = file;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) {
      return _buildPlaceholder();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: Image.file(
        file,
        key: ValueKey(file.path),
        fit: widget.fit,
        alignment: widget.alignment,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        PosterPlaceholder(iconSize: widget.placeholderIconSize);
  }
}

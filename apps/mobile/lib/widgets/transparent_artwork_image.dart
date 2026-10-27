import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays uploaded frame/bubble artwork only when its alpha channel is useful.
/// Broken legacy uploads fall back to vector art instead of painting a square
/// bitmap over the room background or the user's profile photo.
class TransparentArtworkImage extends StatefulWidget {
  const TransparentArtworkImage({
    super.key,
    this.url,
    this.imageProvider,
    required this.fallback,
    this.headers,
    this.fit = BoxFit.contain,
    this.centerSlice,
    this.requireTransparentCenter = false,
    this.filterQuality = FilterQuality.high,
  }) : assert(url != null || imageProvider != null);

  final String? url;
  final ImageProvider<Object>? imageProvider;
  final Map<String, String>? headers;
  final BoxFit fit;
  final Rect? centerSlice;
  final bool requireTransparentCenter;
  final FilterQuality filterQuality;
  final Widget fallback;

  @override
  State<TransparentArtworkImage> createState() => _TransparentArtworkImageState();
}

class _TransparentArtworkImageState extends State<TransparentArtworkImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageProvider<Object>? _provider;
  ImageProvider<Object>? _resolvedSourceProvider;
  String _resolvedUrl = '';
  Map<String, String>? _resolvedHeaders;
  bool? _alphaValid;
  bool _checking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveArtwork();
  }

  @override
  void didUpdateWidget(covariant TransparentArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        !identical(oldWidget.imageProvider, widget.imageProvider) ||
        !mapEquals(oldWidget.headers, widget.headers) ||
        oldWidget.requireTransparentCenter != widget.requireTransparentCenter) {
      _resolveArtwork();
    }
  }

  void _resolveArtwork() {
    final url = widget.url?.trim() ?? '';
    if (url == _resolvedUrl &&
        identical(widget.imageProvider, _resolvedSourceProvider) &&
        mapEquals(_resolvedHeaders, widget.headers)) {
      return;
    }
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _resolvedUrl = url;
    _resolvedSourceProvider = widget.imageProvider;
    _resolvedHeaders = widget.headers == null
        ? null
        : Map<String, String>.from(widget.headers!);
    _alphaValid = null;
    _checking = false;
    _provider = null;
    _stream = null;
    _listener = null;
    final provider = widget.imageProvider ??
        (url.isEmpty ? null : NetworkImage(url, headers: widget.headers));
    if (provider == null) {
      _alphaValid = false;
      return;
    }

    _provider = provider;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _stream = stream;
    _listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (_alphaValid != null || _checking) return;
        _checking = true;
        unawaited(_inspectAlpha(info.image, url));
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted || _resolvedUrl != url) return;
        setState(() {
          _checking = false;
          _alphaValid = false;
        });
      },
    );
    stream.addListener(_listener!);
  }

  Future<void> _inspectAlpha(ui.Image source, String url) async {
    var alphaValid = false;
    ui.Image? sampleImage;
    ui.Picture? picture;
    try {
      const sampleSize = 32;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, sampleSize.toDouble(), sampleSize.toDouble()),
      );
      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, sampleSize.toDouble(), sampleSize.toDouble()),
        ui.Paint()..filterQuality = FilterQuality.none,
      );
      picture = recorder.endRecording();
      final rendered = await picture.toImage(sampleSize, sampleSize);
      sampleImage = rendered;
      final byteData = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData != null) {
        final rgba = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        int alphaAt(int x, int y) => rgba[(y * sampleSize + x) * 4 + 3];
        final corners = <int>[
          alphaAt(1, 1),
          alphaAt(30, 1),
          alphaAt(1, 30),
          alphaAt(30, 30),
        ];
        final outsideClear = corners.every((alpha) => alpha < 16);
        final centreClear =
            !widget.requireTransparentCenter || alphaAt(16, 16) < 16;
        alphaValid = outsideClear && centreClear;
      }
    } catch (_) {
      alphaValid = false;
    } finally {
      sampleImage?.dispose();
      picture?.dispose();
    }
    if (!mounted || _resolvedUrl != url) return;
    setState(() {
      _checking = false;
      _alphaValid = alphaValid;
    });
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_alphaValid != true || _provider == null) return widget.fallback;
    return Image(
      image: _provider!,
      fit: widget.fit,
      centerSlice: widget.centerSlice,
      filterQuality: widget.filterQuality,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}

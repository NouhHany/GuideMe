import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class BackgroundPainter extends StatefulWidget {
  const BackgroundPainter({super.key});

  @override
  _BackgroundPainterState createState() => _BackgroundPainterState();
}

class _BackgroundPainterState extends State<BackgroundPainter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Offset> _imagePositions = [];
  List<double> _imageHeights = [];
  List<double> _speeds = [];
  final List<String> _imageAssets = [
    'assets/images/auth/image (1).jpeg',
    'assets/images/auth/image (2).jpeg',
    'assets/images/auth/image (3).jpeg',
    'assets/images/auth/image (4).jpeg',
    'assets/images/auth/image (5).jpeg',
    'assets/images/auth/image (6).jpeg',
    'assets/images/auth/image (7).jpeg',
    'assets/images/auth/image (8).jpeg',
    'assets/images/auth/image (9).jpeg',
    'assets/images/auth/image (10).jpeg',
    'assets/images/auth/image (11).jpeg',
    'assets/images/auth/image (12).jpeg',
    'assets/images/auth/image (13).jpeg',
    'assets/images/auth/image (14).jpeg',
    'assets/images/auth/image (15).jpeg',
    'assets/images/auth/image (16).jpeg',
    'assets/images/auth/image (17).jpeg',
    'assets/images/auth/image (18).jpeg',
    'assets/images/auth/image (19).jpeg',
    'assets/images/auth/image (20).jpeg',
    'assets/images/auth/image (21).jpeg',
    'assets/images/auth/image (22).jpeg',
  ];
  List<ui.Image>? _images;
  final int _imageCount = 18;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25), // Slower for smoother motion
    )..repeat();
    _loadImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePositionsAndSpeeds();
      setState(() {});
    });
    _controller.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadImages() async {
    try {
      _images = [];
      for (final asset in _imageAssets) {
        final imageProvider = AssetImage(asset);
        final imageStream = imageProvider.resolve(const ImageConfiguration());
        final completer = Completer<ui.Image>();
        ImageStreamListener? listener;
        listener = ImageStreamListener(
          (info, synchronousCall) {
            completer.complete(info.image);
            imageStream.removeListener(listener!);
          },
          onError: (exception, stackTrace) {
            completer.completeError(exception, stackTrace);
            imageStream.removeListener(listener!);
          },
        );
        imageStream.addListener(listener);
        final image = await completer.future;
        _images!.add(image);
      }
      setState(() {});
    } catch (e) {
      _images = [];
      setState(() {});
    }
  }

  void _initializePositionsAndSpeeds() {
    final size = MediaQuery.of(context).size;
    _imagePositions = [];
    _imageHeights = [];
    _speeds = [];

    const int columns = 3;
    const double imageWidth = 120.0;
    const double baseHeight = 160.0;
    const double minHeightVariation = 0.0;
    const double maxHeightVariation = 40.0;
    const double columnSpacing = 20.0;
    const double rowSpacing = 20.0;

    const double virtualWidthMultiplier = 5.0; // Increased for better looping
    double virtualWidth = size.width * virtualWidthMultiplier;
    double columnWidth = (size.width - (columns - 1) * columnSpacing) / columns;
    List<double> columnOffsets = List.generate(
      columns,
      (index) => index * (columnWidth + columnSpacing),
    );
    List<double> columnHeights = List.filled(columns, 0.0);

    int imagesPerColumn = (_imageCount / columns).ceil();
    for (int col = 0; col < columns; col++) {
      double baseX = columnOffsets[col];
      for (int i = 0; i < imagesPerColumn; i++) {
        if (_imagePositions.length >= _imageCount) break;
        double heightVariation =
            minHeightVariation +
            Random().nextDouble() * (maxHeightVariation - minHeightVariation);
        double imageHeight = baseHeight + heightVariation;
        double x =
            baseX +
            (virtualWidth * (i / imagesPerColumn)) +
            (Random().nextDouble() *
                imageWidth *
                0.5); // Slight stagger for better distribution
        double y = columnHeights[col];

        if (y + imageHeight > size.height) {
          y = 0.0;
        }
        _imagePositions.add(Offset(x, y));
        _imageHeights.add(imageHeight);
        columnHeights[col] = y + imageHeight + rowSpacing;
        _speeds.add(0.3);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackgroundPainterCustom(
        imagePositions: _imagePositions,
        imageHeights: _imageHeights,
        speeds: _speeds,
        controllerValue: _controller.value,
        images: _images,
      ),
      child: Container(),
    );
  }
}

class _BackgroundPainterCustom extends CustomPainter {
  final List<Offset> imagePositions;
  final List<double> imageHeights;
  final List<double> speeds;
  final double controllerValue;
  final List<ui.Image>? images;

  _BackgroundPainterCustom({
    required this.imagePositions,
    required this.imageHeights,
    required this.speeds,
    required this.controllerValue,
    required this.images,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, paint);

    if (images == null || images!.isEmpty) {
      return;
    }

    const double virtualWidthMultiplier = 5.0;
    double virtualWidth = size.width * virtualWidthMultiplier;
    const double imageWidth = 120.0;
    const double fadeEdgeWidth = 30.0; // Width of the fade region at the edges

    for (int i = 0; i < imagePositions.length; i++) {
      final image = images![i % images!.length];
      final double imageHeight = imageHeights[i];
      double dx =
          imagePositions[i].dx - (controllerValue * speeds[i] * virtualWidth);
      dx = dx % virtualWidth;
      if (dx < 0) dx += virtualWidth;
      final double screenDx =
          dx %
          (size.width +
              imageWidth); // Extend beyond screen for smooth entry/exit
      final double dy = imagePositions[i].dy;

      // Calculate opacity for fade effect at the edges
      double opacity = 1.0;
      if (screenDx < fadeEdgeWidth) {
        opacity = screenDx / fadeEdgeWidth; // Fade in from left
      } else if (screenDx > size.width - fadeEdgeWidth) {
        opacity = (size.width - screenDx) / fadeEdgeWidth; // Fade out to right
      }

      // Adjust dx to allow partial rendering beyond screen edges
      final double adjustedDx =
          screenDx - (imageWidth / 2); // Center the image for smooth transition

      canvas.save();
      final imageRect = Rect.fromLTWH(adjustedDx, dy, imageWidth, imageHeight);
      final rrect = RRect.fromRectAndRadius(
        imageRect,
        const Radius.circular(15.0),
      );
      canvas.clipRRect(rrect);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        imageRect,
        Paint()..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

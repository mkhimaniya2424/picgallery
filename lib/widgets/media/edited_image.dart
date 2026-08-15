import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/media_model.dart';
import '../../models/edit_recipe.dart';
import '../../core/theme/app_theme.dart';

class EditedImage extends StatefulWidget {
  final MediaModel media;
  final BoxFit fit;
  final double? width;
  final double? height;

  const EditedImage({
    super.key,
    required this.media,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  @override
  State<EditedImage> createState() => _EditedImageState();
}

class _EditedImageState extends State<EditedImage> {
  ui.Image? _image;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(EditedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.displayPath != widget.media.displayPath) {
      setState(() {
        _loading = true;
        _error = false;
        _image = null;
      });
      _loadImage();
    }
  }

  File _getSourceFile() {
    final backup = File('${widget.media.displayPath}.original');
    if (backup.existsSync()) return backup;
    return File(widget.media.displayPath);
  }

  Future<void> _loadImage() async {
    final filePath = widget.media.displayPath;
    if (widget.media.isDisplayPathNetwork) {
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(filePath));
        final response = await request.close();
        final bytes = await consolidateHttpClientResponseBytes(response);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          setState(() {
            _image = frame.image;
            _error = false;
            _loading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('Error loading network image in EditedImage: $e');
        if (mounted) {
          setState(() {
            _error = true;
            _loading = false;
          });
        }
        return;
      }
    }

    final file = _getSourceFile();
    if (!file.existsSync()) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _image = frame.image;
          _error = false;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading image in EditedImage: $e');
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error || _image == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: Icon(Icons.image_not_supported_rounded,
              size: 48, color: Colors.white60),
        ),
      );
    }

    final recipe = widget.media.editRecipe ?? const EditRecipe();

    final double origW = _image!.width.toDouble();
    final double origH = _image!.height.toDouble();

    double rotatedW = origW;
    double rotatedH = origH;
    if (recipe.rotation == 90 || recipe.rotation == 270) {
      rotatedW = origH;
      rotatedH = origW;
    }

    final double cropW = recipe.cropRight - recipe.cropLeft;
    final double cropH = recipe.cropBottom - recipe.cropTop;

    final double displayAspect =
        (cropW <= 0 || cropH <= 0 || rotatedW <= 0 || rotatedH <= 0)
            ? 1.0
            : (cropW * rotatedW) / (cropH * rotatedH);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = widget.width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : rotatedW);
        final double maxH = widget.height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : rotatedH);

        double drawW;
        double drawH;

        if (widget.fit == BoxFit.contain) {
          if (maxW / maxH > displayAspect) {
            drawH = maxH;
            drawW = maxH * displayAspect;
          } else {
            drawW = maxW;
            drawH = maxW / displayAspect;
          }
        } else if (widget.fit == BoxFit.cover) {
          if (maxW / maxH > displayAspect) {
            drawW = maxW;
            drawH = maxW / displayAspect;
          } else {
            drawH = maxH;
            drawW = maxH * displayAspect;
          }
        } else {
          drawW = maxW;
          drawH = maxH;
        }

        return SizedBox(
          width: drawW,
          height: drawH,
          child: CustomPaint(
            painter: _EditedImagePainter(
              image: _image!,
              recipe: recipe,
            ),
          ),
        );
      },
    );
  }
}

class _EditedImagePainter extends CustomPainter {
  final ui.Image image;
  final EditRecipe recipe;

  _EditedImagePainter({
    required this.image,
    required this.recipe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double origW = image.width.toDouble();
    final double origH = image.height.toDouble();

    double rotatedW = origW;
    double rotatedH = origH;
    if (recipe.rotation == 90 || recipe.rotation == 270) {
      rotatedW = origH;
      rotatedH = origW;
    }

    final double cropW = recipe.cropRight - recipe.cropLeft;
    final double cropH = recipe.cropBottom - recipe.cropTop;

    if (cropW <= 0 || cropH <= 0) return;

    // Scale factor mapping crop region to painter size bounds
    final double scale = size.width / (cropW * rotatedW);

    canvas.save();

    // Scale canvas to the coordinate space of the display bounds
    canvas.scale(scale);

    // Position crop region origin at canvas (0,0)
    canvas.translate(-recipe.cropLeft * rotatedW, -recipe.cropTop * rotatedH);

    // Apply rotation and flip around the center of the rotated frame
    canvas.translate(rotatedW / 2, rotatedH / 2);
    canvas.rotate(recipe.rotation * math.pi / 180);
    canvas.scale(
        recipe.flipHorizontal ? -1.0 : 1.0, recipe.flipVertical ? -1.0 : 1.0);
    canvas.translate(-origW / 2, -origH / 2);

    final paint = Paint();
    final hasColorEdits = recipe.hasEdits &&
        (recipe.brightness != 0.0 ||
            recipe.contrast != 0.0 ||
            recipe.saturation != 0.0 ||
            recipe.exposure != 0.0 ||
            recipe.temperature != 0.0 ||
            (recipe.filter != null && recipe.filter != 'none'));

    final colorMatrix = hasColorEdits ? recipe.combinedColorMatrix : null;

    if (recipe.sharpen > 0.0) {
      // Draw base image with (1 + sharpen) scale
      final sharpenMatrix = [
        1.0 + recipe.sharpen,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0 + recipe.sharpen,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0 + recipe.sharpen,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
      ];
      final combinedOriginalMatrix = colorMatrix != null
          ? EditRecipe.multiplyMatrices(sharpenMatrix, colorMatrix)
          : sharpenMatrix;

      final originalPaint = Paint()
        ..colorFilter = ColorFilter.matrix(combinedOriginalMatrix);
      canvas.drawImage(image, Offset.zero, originalPaint);

      // Draw blurred image with -sharpen scale and BlendMode.plus
      final blurMatrix = [
        -recipe.sharpen,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        -recipe.sharpen,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        -recipe.sharpen,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
      ];
      final combinedBlurMatrix = colorMatrix != null
          ? EditRecipe.multiplyMatrices(blurMatrix, colorMatrix)
          : blurMatrix;

      final blurPaint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
            sigmaX: 1.5, sigmaY: 1.5, tileMode: TileMode.clamp)
        ..colorFilter = ColorFilter.matrix(combinedBlurMatrix)
        ..blendMode = BlendMode.plus;
      canvas.drawImage(image, Offset.zero, blurPaint);
    } else {
      if (colorMatrix != null) {
        paint.colorFilter = ColorFilter.matrix(colorMatrix);
      }
      canvas.drawImage(image, Offset.zero, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_EditedImagePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.recipe != recipe;
}

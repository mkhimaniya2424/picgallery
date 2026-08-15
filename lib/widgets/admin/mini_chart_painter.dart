import 'package:flutter/material.dart';

/// Tiny sparkline used inside stat cards. Draws a smooth gradient-stroked
/// line with a soft fill underneath, animatable via [progress].
class SparklinePainter extends CustomPainter {
  final List<double> values;
  final List<Color> gradient;
  final double progress;

  SparklinePainter(
      {required this.values, required this.gradient, this.progress = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1 : (maxV - minV);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - minV) / range) * size.height;
      points.add(Offset(x, y));
    }

    final visibleCount =
        (points.length * progress).clamp(2, points.length).toDouble();
    final visiblePoints = points.take(visibleCount.ceil()).toList();
    if (visiblePoints.length < 2) return;

    final linePath = Path()
      ..moveTo(visiblePoints.first.dx, visiblePoints.first.dy);
    for (var i = 1; i < visiblePoints.length; i++) {
      final prev = visiblePoints[i - 1];
      final curr = visiblePoints[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    linePath.lineTo(visiblePoints.last.dx, visiblePoints.last.dy);

    final fillPath = Path.from(linePath)
      ..lineTo(visiblePoints.last.dx, size.height)
      ..lineTo(visiblePoints.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          gradient.last.withValues(alpha: 0.28),
          gradient.last.withValues(alpha: 0.0)
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: gradient)
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(linePath, linePaint);

    canvas.drawCircle(
      visiblePoints.last,
      3.4,
      Paint()..color = gradient.last,
    );
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.values != values;
}

/// Small self-animating sparkline widget wrapper around [SparklinePainter].
class MiniSparkline extends StatefulWidget {
  final List<double> values;
  final List<Color> gradient;
  final double height;

  const MiniSparkline(
      {super.key,
      required this.values,
      required this.gradient,
      this.height = 36});

  @override
  State<MiniSparkline> createState() => _MiniSparklineState();
}

class _MiniSparklineState extends State<MiniSparkline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: SparklinePainter(
              values: widget.values,
              gradient: widget.gradient,
              progress: _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Rounded gradient bar chart, animatable via [progress] (0..1 grows bars
/// up from the baseline).
class BarsPainter extends CustomPainter {
  final List<double> values;
  final List<Color> gradient;
  final double progress;

  BarsPainter(
      {required this.values, required this.gradient, this.progress = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b) <= 0
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b);
    final barCount = values.length;
    final gap = size.width * 0.06;
    final barWidth = (size.width - gap * (barCount - 1)) / barCount;

    for (var i = 0; i < barCount; i++) {
      final targetH = (values[i] / maxV) * size.height;
      final h = targetH * progress;
      final left = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - h, barWidth, h),
        Radius.circular(barWidth * 0.4),
      );
      final t = barCount == 1 ? 0.0 : i / (barCount - 1);
      final color = Color.lerp(gradient.first, gradient.last, t)!;
      canvas.drawRRect(
          rect,
          Paint()
            ..color = color.withValues(alpha: 0.25 + 0.6 * (i / barCount)));
    }
    // Emphasize the last (current) bar with the full gradient.
    final lastH = (values.last / maxV) * size.height * progress;
    final lastLeft = (barCount - 1) * (barWidth + gap);
    final lastRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(lastLeft, size.height - lastH, barWidth, lastH),
      Radius.circular(barWidth * 0.4),
    );
    canvas.drawRRect(
      lastRect,
      Paint()
        ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradient)
            .createShader(
                Rect.fromLTWH(lastLeft, size.height - lastH, barWidth, lastH)),
    );
  }

  @override
  bool shouldRepaint(covariant BarsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Self-animating bar chart widget wrapper.
class MiniBars extends StatefulWidget {
  final List<double> values;
  final List<Color> gradient;
  final double height;

  const MiniBars(
      {super.key,
      required this.values,
      required this.gradient,
      this.height = 120});

  @override
  State<MiniBars> createState() => _MiniBarsState();
}

class _MiniBarsState extends State<MiniBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: BarsPainter(
              values: widget.values,
              gradient: widget.gradient,
              progress:
                  Curves.easeOutBack.transform(_controller.value).clamp(0, 1)),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Larger area/line chart used in the Performance Analytics section, with
/// a dashed baseline grid and gradient fill.
class AreaChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> gradient;
  final double progress;

  AreaChartPainter(
      {required this.values, required this.gradient, this.progress = 1});

  @override
  void paint(Canvas canvas, Size size) {
    // Grid lines.
    final gridPaint = Paint()
      ..color = const Color(0xFFE9E5FF)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1 : (maxV - minV) * 1.15;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - minV) / range) * size.height - 6;
      points.add(Offset(x, y));
    }

    final visibleCount =
        (points.length * progress).clamp(2, points.length).toDouble();
    final visiblePoints = points.take(visibleCount.ceil()).toList();
    if (visiblePoints.length < 2) return;

    final linePath = Path()
      ..moveTo(visiblePoints.first.dx, visiblePoints.first.dy);
    for (var i = 1; i < visiblePoints.length; i++) {
      final prev = visiblePoints[i - 1];
      final curr = visiblePoints[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    linePath.lineTo(visiblePoints.last.dx, visiblePoints.last.dy);

    final fillPath = Path.from(linePath)
      ..lineTo(visiblePoints.last.dx, size.height)
      ..lineTo(visiblePoints.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradient.last.withValues(alpha: 0.30),
            gradient.last.withValues(alpha: 0.0)
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: gradient)
            .createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    for (final p in visiblePoints) {
      canvas.drawCircle(p, 3.6, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          3.6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = gradient.last);
    }
  }

  @override
  bool shouldRepaint(covariant AreaChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

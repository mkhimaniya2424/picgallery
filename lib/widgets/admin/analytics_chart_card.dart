import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';
import 'mini_chart_painter.dart';

/// A Performance Analytics card: title, subtitle, current value, and a
/// large animated bar or area chart — used for Monthly Uploads, Revenue,
/// Bookings, Storage Growth, and Gallery Views.
class AnalyticsChartCard extends StatelessWidget {
  final AnalyticsSeries series;

  const AnalyticsChartCard({super.key, required this.series});

  bool get _hasData =>
      series.values.isNotEmpty && series.values.any((v) => v > 0);

  @override
  Widget build(BuildContext context) {
    final hasData = _hasData;
    double delta = 0;
    bool up = true;
    if (hasData && series.values.length >= 2) {
      final last = series.values.last;
      final prev = series.values[series.values.length - 2];
      delta = prev == 0 ? 0.0 : ((last - prev) / prev) * 100;
      up = delta >= 0;
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(series.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ),
              if (hasData && series.values.length >= 2) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (up ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${up ? '+' : ''}${delta.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: up ? AppColors.success : AppColors.error),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(series.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.subtitle)),
          const SizedBox(height: AppSpacing.md),
          if (hasData)
            series.isBar
                ? MiniBars(
                    values: series.values,
                    gradient: series.gradient,
                    height: 120)
                : SizedBox(
                    height: 120,
                    child: _AnimatedArea(
                        values: series.values, gradient: series.gradient),
                  )
          else
            SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.show_chart_rounded,
                        size: 26, color: AppColors.subtitle),
                    const SizedBox(height: 8),
                    Text('Not enough data yet',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subtitle)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedArea extends StatefulWidget {
  final List<double> values;
  final List<Color> gradient;

  const _AnimatedArea({required this.values, required this.gradient});

  @override
  State<_AnimatedArea> createState() => _AnimatedAreaState();
}

class _AnimatedAreaState extends State<_AnimatedArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: AreaChartPainter(
            values: widget.values,
            gradient: widget.gradient,
            progress: _controller.value),
        size: Size.infinite,
      ),
    );
  }
}

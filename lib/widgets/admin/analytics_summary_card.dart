import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Small headline-number chip used in the "Analytics Summary" row above
/// the full [AnalyticsChartCard] carousel — a quick at-a-glance readout
/// (Total Photos, Total Videos, Storage, Revenue...) before the person
/// scrolls into the detailed charts.
class AnalyticsSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  const AnalyticsSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark ? AppColors.textOnDark : AppColors.text;
    final labelColor = isDark ? AppColors.subtitleOnDark : AppColors.subtitle;

    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient.first.withValues(alpha: isDark ? 0.18 : 0.09),
            gradient.last.withValues(alpha: isDark ? 0.26 : 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: gradient.last.withValues(alpha: isDark ? 0.28 : 0.18),
        ),
        boxShadow: AppShadows.soft(
          gradient.last,
          opacity: isDark ? 0.12 : 0.06,
          blur: 16,
          y: 8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w700,
              color: valueColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

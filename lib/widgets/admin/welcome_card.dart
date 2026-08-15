import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// The signature purple → violet → pink gradient hero card: a welcome
/// message plus a floating glass mini-stat (Pending Deliveries).
class WelcomeCard extends StatelessWidget {
  final int pendingDeliveries;

  const WelcomeCard({
    super.key,
    this.pendingDeliveries = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.raised(AppColors.primary),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            // Deep-ink base so the gradient reads as rich rather than flat/pastel.
            Container(color: AppColors.ink),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.96),
                      AppColors.secondary.withValues(alpha: 0.96),
                      AppColors.accent.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
            // Decorative blurred orbs for depth.
            Positioned(
              top: -40,
              right: -30,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -20,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      shape: BoxShape.circle),
                ),
              ),
            ),
            // Hairline top sheen so the panel doesn't sit perfectly flat.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.5),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 13, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Text('STUDIO IS THRIVING',
                            style: TextStyle(
                                color: AppColors.gold.withValues(alpha: 0.95),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome back 👋',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        height: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Here's what's happening across your studio today.",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                          child: _MiniStat(
                              icon: Icons.local_shipping_rounded,
                              label: 'Pending Deliveries',
                              value: '$pendingDeliveries')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 17),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10.5,
              fontWeight: FontWeight.w500),
          maxLines: 2,
        ),
      ],
    );
  }
}

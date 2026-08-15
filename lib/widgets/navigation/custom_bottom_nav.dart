import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Floating, rounded-pill bottom navigation bar with a gradient highlight
/// on the selected item — used to avoid the default flat Material
/// [BottomNavigationBar] look on the client's bottom-nav screens.
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav(
      {super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.photo_library_rounded, label: 'Gallery'),
    (icon: Icons.notifications_rounded, label: 'Alerts'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String getLabel(int index) {
      switch (index) {
        case 0:
          return l10n.home;
        case 1:
          return l10n.gallery;
        case 2:
          return l10n.notifications;
        case 3:
          return l10n.profile;
        default:
          return '';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_items.length, (i) {
            final selected = i == currentIndex;
            final item = _items[i];
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppDurations.fast,
                padding: EdgeInsets.symmetric(
                    horizontal: selected ? 18 : 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.buttonGradient : null,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  children: [
                    Icon(item.icon,
                        size: 20,
                        color: selected ? Colors.white : AppColors.subtitle),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Text(getLabel(i),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

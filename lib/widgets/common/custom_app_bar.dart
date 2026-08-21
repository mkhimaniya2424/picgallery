import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The single AppBar used on every screen in the app, so headers stay
/// pixel- AND color-consistent everywhere instead of screens hand-rolling
/// their own header rows or sitting transparent/plain. Automatically
/// adapts icon/title colors to the current light/dark theme.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final VoidCallback? onBack;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = true,
    this.leading,
    this.centerTitle = true,
    this.bottom,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: centerTitle,
      titleSpacing: leading != null ? 4 : NavigationToolbar.kMiddleSpacing,
      automaticallyImplyLeading: showBack,
      leadingWidth: leading != null ? 64 : null,
      iconTheme: IconThemeData(color: onSurface),
      actionsIconTheme: IconThemeData(color: onSurface),
      leading: leading ??
          (showBack
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                )
              : null),
      title: titleWidget ??
          (title != null
              ? Text(title!,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onSurface))
              : null),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}

/// Soft round icon button for use on the flat app bar — the back arrow
/// on [CustomAppBar] and also reused directly by screens that need a
/// matching round icon action (e.g. the Home tab's notification bell) so
/// every round icon in the header shares the exact same size, fill and
/// border.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const GlassIconButton(
      {super.key, required this.icon, this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return _GlassIconButton(icon: icon, onTap: onTap, size: size);
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _GlassIconButton({required this.icon, this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final bgColor = isDark
        ? AppColors.darkSurfaceRaised.withValues(alpha: 0.7)
        : AppColors.primary.withValues(alpha: 0.1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: size * 0.4, color: onSurface),
      ),
    );
  }
}

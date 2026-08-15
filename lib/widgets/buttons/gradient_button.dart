import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Premium gradient call-to-action button with a subtle press-scale
/// micro-interaction and a built-in loading spinner. Used for every
/// primary action across the auth flow (Sign In, Create Account, Send
/// Reset Link, Continue, Save...).
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Gradient gradient;
  final bool outlined;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradient = AppColors.buttonGradient,
    this.outlined = false,
    this.height = 58,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  double _scale = 1;

  void _setScale(double v) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _scale = v);
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: widget.outlined ? AppColors.primary : Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 20,
                    color: widget.outlined ? AppColors.primary : Colors.white),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: widget.outlined ? AppColors.primary : Colors.white,
                    ),
              ),
            ],
          );

    return GestureDetector(
      onTapDown: (_) => _setScale(0.97),
      onTapUp: (_) => _setScale(1),
      onTapCancel: () => _setScale(1),
      child: AnimatedScale(
        scale: _scale,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: widget.outlined ? null : widget.gradient,
            border: widget.outlined
                ? Border.all(color: AppColors.primary, width: 1.6)
                : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: widget.outlined
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.32),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: widget.isLoading ? null : widget.onPressed,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

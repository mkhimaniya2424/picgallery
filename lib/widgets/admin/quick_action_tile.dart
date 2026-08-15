import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';

/// A single large, rounded Quick Action tile with a soft gradient wash,
/// a bold gradient icon badge, and a subtle press-scale interaction —
/// deliberately not a default [Card]/[ElevatedButton].
class QuickActionTile extends StatefulWidget {
  final QuickActionData data;
  final VoidCallback? onTap;

  const QuickActionTile({super.key, required this.data, this.onTap});

  @override
  State<QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<QuickActionTile> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.soft(widget.data.gradient.last,
                opacity: 0.08, blur: 18, y: 9),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: widget.data.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color:
                            widget.data.gradient.last.withValues(alpha: 0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Icon(widget.data.icon, color: Colors.white, size: 21),
              ),
              const SizedBox(height: 8),
              Text(
                widget.data.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

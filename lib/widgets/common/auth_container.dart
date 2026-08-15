import 'package:flutter/material.dart';

/// Lays out a single auth-flow page (Login, Register step, Forgot
/// Password...) so it never looks "spread across the whole page":
///
/// * Content is capped at [maxWidth] and centered horizontally, so it
///   doesn't stretch edge-to-edge on tablets / wide or foldable screens.
/// * Content sits at the top by default ([mainAxisAlignment]), or can be
///   centered vertically for very short screens if desired.
/// * It still scrolls normally (and stays reachable above the keyboard)
///   when content is taller than the available height.
class AuthContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;
  final MainAxisAlignment mainAxisAlignment;

  const AuthContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.maxWidth = 440,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fallback for the (now rare, after the ScreenBackdrop fix)
        // case where an ancestor still hands this an unbounded height
        // — without this, minHeight could resolve to infinity and
        // force an infinitely-tall Column (a real overflow), which is
        // what caused the yellow/black hazard-stripe warning banner
        // on some screen shapes.
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;
        final minHeight =
            (availableHeight - padding.vertical).clamp(0.0, double.infinity);
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            // IntrinsicHeight gives this Column an actual resolved height
            // (at least minHeight) instead of shrink-wrapping to content,
            // which is what lets mainAxisAlignment below genuinely control
            // where the content sits (top vs centered) instead of a plain
            // Center silently overriding it.
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: mainAxisAlignment,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
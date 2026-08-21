import 'package:flutter/material.dart';

import '../../core/utils/responsive_utils.dart';

/// Lays out a single auth-flow page (Login, Register step, Forgot
/// Password...) so it never looks "spread across the whole page":
///
/// * Content is capped at [maxWidth] (defaults to
///   [ResponsiveUtils.formMaxWidth], the app-wide form-width cap — see
///   that class for the full breakpoint system) and centered
///   horizontally, so it doesn't stretch edge-to-edge on tablets, fold
///   inner screens, or wide desktop/web windows.
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
    this.maxWidth = ResponsiveUtils.formMaxWidth,
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
            // Column(mainAxisSize: MainAxisSize.max) already stretches to
            // fill the minHeight constraint above on its own, which is
            // what lets mainAxisAlignment below genuinely control where
            // the content sits (top vs centered). This used to be wrapped
            // in IntrinsicHeight to force a resolved height, but
            // IntrinsicHeight computes each child's height via an
            // *approximate* intrinsic-height algorithm rather than real
            // layout — for widgets like TextFormField (used by
            // CustomTextField) that approximation can drift from the
            // actual rendered height by a few pixels, especially once an
            // extra child (e.g. the "wrong sign-in method" error banner)
            // or a shrinking keyboard-adjusted viewport changes the mix.
            // That drift is exactly what produced the intermittent
            // "RenderFlex overflowed by N pixels" hazard-stripe warning.
            // It's redundant anyway once minHeight + mainAxisSize.max are
            // already in place, so it's removed rather than patched.
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
        );
      },
    );
  }
}
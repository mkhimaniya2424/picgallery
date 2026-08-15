import 'package:flutter/material.dart';

/// Low-level building block for popups/menus that must stay correctly
/// anchored to the widget that opened them.
///
/// This is the single place that implements the actual positioning math:
///
///  * Opens the menu directly **below** [child] when there is enough room.
///  * Flips it **above** [child] when there isn't.
///  * Clamps the menu so it never renders past the top/bottom/left/right
///    edges of the screen, and stays clear of [MediaQuery] safe-area /
///    system-inset regions (status bar, notches, keyboard, nav bar).
///  * Uses [CompositedTransformTarget]/[CompositedTransformFollower], so if
///    [child] moves (e.g. it sits inside something scrollable) the open
///    menu moves with it instead of staying pinned to a stale position.
///  * Never uses a hardcoded screen coordinate or device-specific offset —
///    every measurement is taken from the real render tree at open time,
///    so this works the same on any screen size/resolution.
///  * Closes on an outside tap via a transparent full-screen barrier.
///
/// Other widgets (e.g. [AnchoredDropdownField] and the compact toolbar
/// dropdown used on the Media screen) should build on top of this instead
/// of re-implementing their own [OverlayEntry]/[LayerLink] plumbing.
class AnchoredMenu extends StatefulWidget {
  const AnchoredMenu({
    super.key,
    required this.child,
    required this.menuBuilder,
    this.menuWidth,
    this.maxMenuHeight = 320,
    this.gap = 6,
    this.screenMargin = 8,
    this.controller,
  });

  /// The trigger widget (the thing that gets tapped to open the menu).
  final Widget child;

  /// Builds the menu content. [close] can be called by menu items to
  /// dismiss the menu (e.g. after a selection).
  final Widget Function(BuildContext context, VoidCallback close) menuBuilder;

  /// Width of the menu. Defaults to the trigger's own width so it reads as
  /// a natural extension of the control that opened it.
  final double? menuWidth;

  /// Largest the menu is allowed to grow before it starts scrolling.
  final double maxMenuHeight;

  /// Visual gap between the trigger and the menu.
  final double gap;

  /// Minimum distance to keep between the menu and the screen edges.
  final double screenMargin;

  /// Optional controller so a parent can open/close/toggle the menu (e.g.
  /// to drive a dropdown-style trigger button).
  final AnchoredMenuController? controller;

  @override
  State<AnchoredMenu> createState() => _AnchoredMenuState();
}

/// Lets a parent widget (typically the [child] passed to [AnchoredMenu])
/// open, close, or toggle the menu, and know whether it's open.
class AnchoredMenuController extends ChangeNotifier {
  _AnchoredMenuState? _state;

  bool get isOpen => _state?._entry != null;

  void open() => _state?._open();
  void close() => _state?._close();
  void toggle() => _state?._toggle();

  /// Called by [_AnchoredMenuState] when the menu opens or closes so
  /// listeners (e.g. a dropdown trigger button) can rebuild.
  // ignore: use_setters_to_change_properties
  void _notify() => notifyListeners();
}

class _AnchoredMenuState extends State<AnchoredMenu> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  // Guards against scheduling more than one pending overlay refresh at a
  // time (e.g. several didUpdateWidget calls in quick succession while
  // rapidly switching between toolbar dropdowns).
  bool _overlayRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant AnchoredMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    // Keep an already-open menu in sync if its content changes underneath
    // it (e.g. the selected value updates while the menu is open).
    //
    // This must NOT call OverlayEntry.markNeedsBuild() synchronously here:
    // didUpdateWidget runs during the build phase, and the framework
    // forbids marking anything dirty (setState/markNeedsBuild) while it's
    // already in the middle of building widgets. Doing so throws
    // "setState() or markNeedsBuild() called during build" and can leave
    // the overlay's render subtree in a half-updated state for that frame
    // (visible as a huge bogus RenderFlex overflow). Instead, only request
    // a refresh — the actual rebuild happens safely after the frame.
    _scheduleOverlayRefresh();
  }

  void _scheduleOverlayRefresh() {
    // Nothing to refresh if the menu isn't open, and no need to queue a
    // second callback if one is already pending.
    if (_entry == null || _overlayRefreshScheduled) return;
    _overlayRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayRefreshScheduled = false;
      // The widget may have been disposed, or the menu may have been
      // closed, while this callback was pending.
      if (!mounted || _entry == null) return;
      _entry!.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _close() {
    if (_entry == null) return;
    _entry?.remove();
    _entry = null;
    widget.controller?._notify();
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final anchorBox = context.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) return;

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;

    final anchorSize = anchorBox.size;
    final menuWidth = widget.menuWidth ?? anchorSize.width;

    // Measure available space using the real, current render tree — never
    // a fixed/hardcoded coordinate — so this adapts to any screen size,
    // orientation, or scroll position at the moment the menu is opened.
    final mediaQuery = MediaQuery.of(context);
    final screenSize = overlayBox?.size ?? mediaQuery.size;
    final anchorTopLeft = overlayBox != null
        ? anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox)
        : anchorBox.localToGlobal(Offset.zero);

    // Respect SafeArea / system insets (status bar, notch, keyboard, nav
    // bar) rather than treating the raw screen rect as usable space.
    final topInset = mediaQuery.padding.top;
    final bottomInset =
        mediaQuery.padding.bottom + mediaQuery.viewInsets.bottom;

    final spaceBelow = screenSize.height -
        bottomInset -
        widget.screenMargin -
        (anchorTopLeft.dy + anchorSize.height);
    final spaceAbove = anchorTopLeft.dy - topInset - widget.screenMargin;

    // Prefer opening below; flip above only when below doesn't have
    // reasonable room and above has more room to offer.
    const minComfortableHeight = 120.0;
    final openBelow =
        spaceBelow >= minComfortableHeight || spaceBelow >= spaceAbove;

    final availableHeight = openBelow ? spaceBelow : spaceAbove;
    final menuHeight = availableHeight.clamp(80.0, widget.maxMenuHeight);

    // Clamp horizontally so the menu never runs off the left/right edge of
    // the screen, regardless of where the trigger sits (e.g. near the end
    // of a horizontally-scrolling toolbar).
    final maxLeft = screenSize.width - widget.screenMargin - menuWidth;
    final minLeft = widget.screenMargin;
    double dx = 0;
    if (anchorTopLeft.dx > maxLeft) {
      dx = maxLeft - anchorTopLeft.dx;
    }
    if (anchorTopLeft.dx + dx < minLeft) {
      dx = minLeft - anchorTopLeft.dx;
    }

    _entry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // Invisible full-screen barrier: tapping anywhere outside the
            // menu closes it, without blocking the rest of the app.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor:
                  openBelow ? Alignment.bottomLeft : Alignment.topLeft,
              followerAnchor:
                  openBelow ? Alignment.topLeft : Alignment.bottomLeft,
              offset: Offset(dx, openBelow ? widget.gap : -widget.gap),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: menuWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: menuHeight),
                    child: widget.menuBuilder(overlayContext, _close),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
    widget.controller?._notify();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: widget.child,
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A wrapper that handles trackpad pinch-to-zoom on Web (specifically Windows),
/// where trackpad pinches are dispatched as PointerScrollEvent with the Ctrl key pressed.
/// It also handles PointerScaleEvent which is emitted by some platforms.
class PinchZoomHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const PinchZoomHandler({
    Key? key,
    required this.child,
    required this.onZoomIn,
    required this.onZoomOut,
  }) : super(key: key);

  @override
  State<PinchZoomHandler> createState() => _PinchZoomHandlerState();
}

class _PinchZoomHandlerState extends State<PinchZoomHandler> {
  double _scrollPinchAccumulator = 0.0;
  DateTime _lastScrollPinchTime = DateTime.now();

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent &&
        HardwareKeyboard.instance.isControlPressed) {
      final now = DateTime.now();
      if (now.difference(_lastScrollPinchTime).inMilliseconds > 300) {
        _scrollPinchAccumulator = 0.0;
      }
      _lastScrollPinchTime = now;
      _scrollPinchAccumulator += event.scrollDelta.dy;

      // Threshold to trigger a zoom step.
      if (_scrollPinchAccumulator > 80) {
        widget.onZoomOut();
        _scrollPinchAccumulator = 0.0;
      } else if (_scrollPinchAccumulator < -80) {
        widget.onZoomIn();
        _scrollPinchAccumulator = 0.0;
      }
    } else if (event is PointerScaleEvent) {
      if (event.scale > 1.05) {
        widget.onZoomIn();
      } else if (event.scale < 0.95) {
        widget.onZoomOut();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: widget.child,
    );
  }
}

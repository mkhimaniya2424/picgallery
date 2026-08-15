import 'package:flutter/material.dart';

/// Animates a displayed value from its previous numeric value up (or
/// down) to a new one whenever [value] changes — e.g. "128" -> "142"
/// counts through the intermediate numbers instead of just snapping.
///
/// Non-numeric characters around the number (₹, K, L, %, GB, ...) are
/// preserved as a prefix/suffix so it works directly with already
/// formatted [StatCardData.value] strings like "₹8.4L" or "68 GB".
class CountUpText extends StatefulWidget {
  final String value;
  final TextStyle? style;

  const CountUpText({super.key, required this.value, this.style});

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _ParsedValue {
  final String prefix;
  final double number;
  final String suffix;
  final int decimals;

  /// False for values with no numeric content at all (e.g. "Not tracked
  /// yet") — [_CountUpTextState.build] must not synthesize a "0" in
  /// front of these; there's nothing to count up from/to.
  final bool hasNumber;
  const _ParsedValue(this.prefix, this.number, this.suffix, this.decimals,
      {this.hasNumber = true});
}

_ParsedValue _parse(String raw) {
  final match = RegExp(r'^([^\d]*)([\d,]*\.?\d*)([^\d]*)$').firstMatch(raw);
  if (match == null || match.group(2)!.isEmpty) {
    return _ParsedValue('', 0, raw, 0, hasNumber: false);
  }
  final numStr = match.group(2)!.replaceAll(',', '');
  final decimals = numStr.contains('.') ? numStr.split('.').last.length : 0;
  return _ParsedValue(
      match.group(1)!, double.tryParse(numStr) ?? 0, match.group(3)!, decimals);
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late _ParsedValue _from;
  late _ParsedValue _to;

  @override
  void initState() {
    super.initState();
    _to = _parse(widget.value);
    _from = const _ParsedValue('', 0, '', 0);
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = _parse(oldWidget.value);
      _to = _parse(widget.value);
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A purely-text value ("Not tracked yet") has nothing to count up
    // from/to — show it as-is, at a smaller size than the big KPI
    // numbers use so a longer phrase still fits on one line instead of
    // wrapping and overflowing its fixed-height card.
    if (!_to.hasNumber) {
      final baseSize = widget.style?.fontSize ?? 24;
      return Text(
        _to.suffix,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (widget.style ?? const TextStyle())
            .copyWith(fontSize: baseSize * 0.62),
      );
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final current =
            _from.number + (_to.number - _from.number) * _animation.value;
        final text =
            '${_to.prefix}${current.toStringAsFixed(_to.decimals)}${_to.suffix}';
        return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: widget.style);
      },
    );
  }
}

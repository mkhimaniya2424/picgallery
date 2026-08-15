import 'package:flutter/material.dart';

/// Displays [text] while visually highlighting all case-insensitive
/// occurrences of [query].
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQ = q.toLowerCase();

    final spans = <InlineSpan>[];
    int start = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerQ, start);
      if (idx < 0) break;

      if (idx > start) {
        spans.add(TextSpan(
          text: text.substring(start, idx),
          style: style,
        ));
      }

      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: (highlightStyle ??
            (style ?? const TextStyle()).copyWith(
              color: Colors.white,
              backgroundColor: Colors.black,
              fontWeight: FontWeight.w700,
            )),
      ));

      start = idx + q.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans, style: style),
    );
  }
}

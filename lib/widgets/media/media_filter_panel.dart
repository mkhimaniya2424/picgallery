import 'package:flutter/material.dart';

/// Placeholder widget for the Phase 4 Part 3 filter panel.
///
/// The actual multi-dimension filter UI will be implemented once the
/// controller supports date/size/resolution filtering.
class MediaFilterPanel extends StatelessWidget {
  final VoidCallback onReset;
  final Widget child;

  const MediaFilterPanel(
      {super.key, required this.onReset, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reset filters'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Freeform "type a value, press enter/tap add to turn it into a chip"
/// input for list-type fields with no fixed option set (e.g. Service
/// Areas, Languages) — the multi-select sibling of [FilterChip]-based
/// pickers used for fixed vocabularies like `kStudioSpecializations`.
class TagInputField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const TagInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.values,
    required this.onChanged,
  });

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  final _controller = TextEditingController();

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty || widget.values.contains(value)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.values, value]);
    _controller.clear();
  }

  void _remove(String value) {
    widget.onChanged(widget.values.where((v) => v != value).toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, color: colorScheme.primary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(Icons.add_circle_rounded, color: colorScheme.primary),
              onPressed: _add,
            ),
          ),
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.values.map((value) {
              return Chip(
                label: Text(value),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                backgroundColor: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white.withValues(alpha: 0.7),
                side: BorderSide(color: colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                deleteIcon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                onDeleted: () => _remove(value),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

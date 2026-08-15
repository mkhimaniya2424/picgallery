import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class FaqItem {
  final String question;
  final String answer;

  const FaqItem({
    required this.question,
    required this.answer,
  });

  /// Builds a [FaqItem] from the backend's `FaqItemOut` shape
  /// (`app/schemas/legal.py`): `{question, answer}`.
  factory FaqItem.fromApiJson(Map<String, dynamic> json) {
    return FaqItem(
      question: json['question'] as String,
      answer: json['answer'] as String,
    );
  }
}

class FaqSectionData {
  final String title;
  final List<FaqItem> items;

  const FaqSectionData({
    required this.title,
    required this.items,
  });

  /// Builds a [FaqSectionData] from the backend's `FaqSectionOut` shape
  /// (`app/schemas/legal.py`): `{title, items}`.
  factory FaqSectionData.fromApiJson(Map<String, dynamic> json) {
    return FaqSectionData(
      title: json['title'] as String,
      items: (json['items'] as List)
          .map((i) => FaqItem.fromApiJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Generic expandable FAQ renderer driven entirely by [FaqSectionData].
class ExpandableFaqSection extends StatelessWidget {
  final FaqSectionData section;

  const ExpandableFaqSection({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        ...section.items.map((item) {
          return _FaqTile(item: item);
        }).toList(),
      ],
    );
  }
}

class _FaqTile extends StatefulWidget {
  final FaqItem item;

  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        color: Colors.white,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.subtitle,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                widget.item.answer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

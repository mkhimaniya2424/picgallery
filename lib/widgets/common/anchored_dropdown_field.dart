import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'anchored_menu.dart';

/// Drop-in replacement for [DropdownButtonFormField].
///
/// Material's [DropdownButton] (and therefore [DropdownButtonFormField])
/// opens its menu by aligning the *selected* item with the field, which
/// means the menu is painted directly on top of the field itself — and,
/// whenever the menu is taller than the gap to whatever sits below it (a
/// very common case for compact filter rows stacked close together), on
/// top of those neighbouring widgets too, hiding them completely while
/// the menu is open.
///
/// [AnchoredDropdownField] keeps the same `value` / `items` / `onChanged`
/// / `decoration` / `validator` API as [DropdownButtonFormField] (so it
/// can be swapped in without touching surrounding form logic) but always
/// opens its option list anchored to the field like a normal
/// search-suggestions list — below when there's room, above when there
/// isn't, and always clamped inside the visible screen — so the field and
/// the controls around it stay visible instead of being covered.
///
/// The actual anchoring/positioning logic lives in [AnchoredMenu]; this
/// widget just supplies the trigger's field-style visuals and the menu's
/// list-of-items content.
class AnchoredDropdownField<T> extends FormField<T> {
  AnchoredDropdownField({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.decoration,
    this.hint,
    this.maxMenuHeight = 280,
    super.validator,
    AutovalidateMode? autovalidateMode,
  }) : super(
          initialValue: value,
          autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
          builder: (field) {
            final state = field as _AnchoredDropdownFieldState<T>;
            final w = state.widget;

            return _AnchoredDropdownFieldBody<T>(
              items: w.items,
              value: field.value,
              hint: w.hint,
              enabled: w.onChanged != null,
              maxMenuHeight: w.maxMenuHeight,
              errorText: field.errorText,
              decoration: w.decoration,
              onChanged: w.onChanged == null ? null : state.didChange,
            );
          },
        );

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final InputDecoration? decoration;
  final Widget? hint;
  final double maxMenuHeight;

  @override
  FormFieldState<T> createState() => _AnchoredDropdownFieldState<T>();
}

/// Mirrors [DropdownButtonFormField]'s own state class: keeps the field's
/// displayed value in sync if the parent rebuilds with a *new* `value`
/// from outside (e.g. an external provider resetting a filter) rather
/// than only updating in response to this field's own [onChanged].
class _AnchoredDropdownFieldState<T> extends FormFieldState<T> {
  @override
  AnchoredDropdownField<T> get widget =>
      super.widget as AnchoredDropdownField<T>;

  @override
  void didChange(T? value) {
    super.didChange(value);
    widget.onChanged?.call(value);
  }

  @override
  void didUpdateWidget(covariant AnchoredDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      setValue(widget.value);
    }
  }
}

class _AnchoredDropdownFieldBody<T> extends StatefulWidget {
  const _AnchoredDropdownFieldBody({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.enabled,
    required this.maxMenuHeight,
    this.hint,
    this.errorText,
    this.decoration,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final double maxMenuHeight;
  final Widget? hint;
  final String? errorText;
  final InputDecoration? decoration;

  @override
  State<_AnchoredDropdownFieldBody<T>> createState() =>
      _AnchoredDropdownFieldBodyState<T>();
}

class _AnchoredDropdownFieldBodyState<T>
    extends State<_AnchoredDropdownFieldBody<T>> {
  final AnchoredMenuController _controller = AnchoredMenuController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onMenuStateChanged);
  }

  void _onMenuStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onMenuStateChanged);
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMenu(BuildContext context, VoidCallback close) {
    return Material(
      elevation: 8,
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: widget.items.map((item) {
          final selected = item.value == widget.value;
          return InkWell(
            onTap: () {
              close();
              widget.onChanged?.call(item.value);
            },
            child: Container(
              color:
                  selected ? AppColors.primary.withValues(alpha: 0.08) : null,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 14),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.text,
                ),
                child: item.child,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.items.where((i) => i.value == widget.value);
    final display = matches.isNotEmpty ? matches.first.child : widget.hint;

    return AnchoredMenu(
      controller: _controller,
      maxMenuHeight: widget.maxMenuHeight,
      menuBuilder: _buildMenu,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: widget.enabled ? _controller.toggle : null,
        child: InputDecorator(
          isEmpty: display == null,
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            enabled: widget.enabled,
            errorText: widget.errorText,
            suffixIcon: Icon(
              _controller.isOpen
                  ? Icons.arrow_drop_up_rounded
                  : Icons.arrow_drop_down_rounded,
            ),
          ),
          child: display,
        ),
      ),
    );
  }
}

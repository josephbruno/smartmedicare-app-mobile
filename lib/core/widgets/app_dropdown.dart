import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Computes a dropdown menu [itemHeight] that fits scaled desktop text.
double appDropdownItemHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  // Default Material height is 48; grow with text scale so glyphs are not clipped.
  return math.max(
    kMinInteractiveDimension,
    kMinInteractiveDimension * scale + 8,
  );
}

/// [DropdownButtonFormField] that keeps selected text fully visible when the
/// app applies an elevated [TextScaler] (web / desktop).
class AppDropdownButtonFormField<T> extends StatelessWidget {
  const AppDropdownButtonFormField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.decoration,
    this.validator,
    this.onSaved,
    this.hint,
    this.disabledHint,
    this.selectedItemBuilder,
    this.isExpanded = true,
    this.isDense = true,
    this.autovalidateMode,
    this.focusNode,
    this.icon,
    this.style,
    this.dropdownColor,
    this.menuMaxHeight,
    this.borderRadius,
    this.alignment = AlignmentDirectional.centerStart,
    this.enableFeedback,
  });

  final List<DropdownMenuItem<T>>? items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final InputDecoration? decoration;
  final FormFieldValidator<T>? validator;
  final FormFieldSetter<T>? onSaved;
  final Widget? hint;
  final Widget? disabledHint;
  final DropdownButtonBuilder? selectedItemBuilder;
  final bool isExpanded;
  final bool isDense;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final Widget? icon;
  final TextStyle? style;
  final Color? dropdownColor;
  final double? menuMaxHeight;
  final BorderRadius? borderRadius;
  final AlignmentGeometry alignment;
  final bool? enableFeedback;

  @override
  Widget build(BuildContext context) {
    final height = appDropdownItemHeight(context);
    final theme = Theme.of(context);
    final baseDecoration = decoration ?? const InputDecoration();
    final themePadding = theme.inputDecorationTheme.contentPadding;
    final resolvedPadding = baseDecoration.contentPadding ?? themePadding;

    // Dense + balanced padding keeps floating-label fields from clipping
    // the closed-button text (common with FloatingLabelBehavior.always).
    final paddedDecoration = baseDecoration.copyWith(
      isDense: true,
      contentPadding: _contentPadding(resolvedPadding),
    );

    final textStyle = style ??
        theme.textTheme.bodyLarge?.copyWith(height: 1.2) ??
        const TextStyle(height: 1.2);

    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: paddedDecoration,
      validator: validator,
      onSaved: onSaved,
      hint: hint,
      disabledHint: disabledHint,
      selectedItemBuilder: selectedItemBuilder == null
          ? null
          : (ctx) => selectedItemBuilder!(ctx)
              .map(_wrapSelectedChild)
              .toList(growable: false),
      isExpanded: isExpanded,
      isDense: isDense,
      itemHeight: height,
      autovalidateMode: autovalidateMode,
      focusNode: focusNode,
      icon: icon,
      style: textStyle,
      dropdownColor: dropdownColor,
      menuMaxHeight: menuMaxHeight,
      borderRadius: borderRadius,
      alignment: alignment,
      enableFeedback: enableFeedback,
    );
  }

  static EdgeInsetsGeometry _contentPadding(EdgeInsetsGeometry? padding) {
    final resolved = padding?.resolve(TextDirection.ltr) ??
        const EdgeInsets.fromLTRB(16, 20, 16, 20);
    // Slightly less bottom padding so closed-button glyphs aren't clipped.
    return EdgeInsets.fromLTRB(
      resolved.left,
      math.max(resolved.top, 18),
      math.max(resolved.right, 8),
      math.max(resolved.bottom - 4, 14),
    );
  }

  static Widget _wrapSelectedChild(Widget child) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DefaultTextStyle.merge(
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          child: child,
        ),
      ),
    );
  }
}

/// Plain [DropdownButton] with the same scaled [itemHeight] fix.
class AppDropdownButton<T> extends StatelessWidget {
  const AppDropdownButton({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hint,
    this.disabledHint,
    this.selectedItemBuilder,
    this.isExpanded = false,
    this.isDense = false,
    this.underline,
    this.icon,
    this.style,
    this.dropdownColor,
    this.menuMaxHeight,
    this.borderRadius,
    this.padding,
    this.focusNode,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final List<DropdownMenuItem<T>>? items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final Widget? hint;
  final Widget? disabledHint;
  final DropdownButtonBuilder? selectedItemBuilder;
  final bool isExpanded;
  final bool isDense;
  final Widget? underline;
  final Widget? icon;
  final TextStyle? style;
  final Color? dropdownColor;
  final double? menuMaxHeight;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final FocusNode? focusNode;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    // Dense menus stay compact; otherwise grow with text scale so labels aren't clipped.
    final height = isDense ? null : appDropdownItemHeight(context);
    return DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      hint: hint,
      disabledHint: disabledHint,
      selectedItemBuilder: selectedItemBuilder,
      isExpanded: isExpanded,
      isDense: isDense,
      itemHeight: height,
      underline: underline,
      icon: icon,
      style: style,
      dropdownColor: dropdownColor,
      menuMaxHeight: menuMaxHeight,
      borderRadius: borderRadius,
      padding: padding,
      focusNode: focusNode,
      alignment: alignment,
    );
  }
}

/// Form field that opens a searchable list picker (filter-as-you-type).
class AppSearchableDropdownField<T> extends StatelessWidget {
  const AppSearchableDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.displayText,
    this.clearLabel = '—',
    this.allowClear = true,
    this.searchHint = 'Search…',
    this.isDense = true,
  });

  final String label;
  final T? value;
  final List<AppSearchableOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? displayText;
  final String clearLabel;
  final bool allowClear;
  final String searchHint;
  final bool isDense;

  String _labelFor(T v) {
    if (displayText != null) return displayText!(v);
    for (final o in options) {
      if (o.value == v) return o.label;
    }
    return v.toString();
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showDialog<_SearchPickResult<T>>(
      context: context,
      builder: (ctx) => _SearchablePickerDialog<T>(
        title: label,
        options: options,
        selected: value,
        clearLabel: clearLabel,
        allowClear: allowClear,
        searchHint: searchHint,
      ),
    );
    if (result == null) return;
    onChanged(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themePadding = theme.inputDecorationTheme.contentPadding;
    final text = value == null ? null : _labelFor(value as T);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openPicker(context),
      child: InputDecorator(
        isEmpty: text == null,
        decoration: InputDecoration(
          labelText: label,
          isDense: isDense,
          contentPadding: AppDropdownButtonFormField._contentPadding(themePadding),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          text ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.2),
        ),
      ),
    );
  }
}

class AppSearchableOption<T> {
  const AppSearchableOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _SearchPickResult<T> {
  const _SearchPickResult(this.value);
  final T? value;
}

class _SearchablePickerDialog<T> extends StatefulWidget {
  const _SearchablePickerDialog({
    required this.title,
    required this.options,
    required this.selected,
    required this.clearLabel,
    required this.allowClear,
    required this.searchHint,
  });

  final String title;
  final List<AppSearchableOption<T>> options;
  final T? selected;
  final String clearLabel;
  final bool allowClear;
  final String searchHint;

  @override
  State<_SearchablePickerDialog<T>> createState() =>
      _SearchablePickerDialogState<T>();
}

class _SearchablePickerDialogState<T> extends State<_SearchablePickerDialog<T>> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<AppSearchableOption<T>> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.label.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final maxH = MediaQuery.sizeOf(context).height * 0.55;

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              focusNode: _focus,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _query.clear()),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No matches'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount:
                          filtered.length + (widget.allowClear ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (widget.allowClear && index == 0) {
                          return ListTile(
                            dense: true,
                            title: Text(widget.clearLabel),
                            selected: widget.selected == null,
                            onTap: () => Navigator.pop(
                              context,
                              _SearchPickResult<T>(null),
                            ),
                          );
                        }
                        final o = filtered[index - (widget.allowClear ? 1 : 0)];
                        final selected = widget.selected == o.value;
                        return ListTile(
                          dense: true,
                          title: Text(o.label),
                          selected: selected,
                          trailing: selected
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onTap: () => Navigator.pop(
                            context,
                            _SearchPickResult(o.value),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

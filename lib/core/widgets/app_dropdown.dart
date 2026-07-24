import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Computes a dropdown [itemHeight] that fits scaled desktop text.
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
    final baseDecoration = decoration ?? const InputDecoration();
    final themePadding = Theme.of(context).inputDecorationTheme.contentPadding;
    final resolvedPadding = baseDecoration.contentPadding ?? themePadding;
    final paddedDecoration = baseDecoration.copyWith(
      contentPadding: _bumpVerticalPadding(resolvedPadding),
    );

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
      itemHeight: height,
      autovalidateMode: autovalidateMode,
      focusNode: focusNode,
      icon: icon,
      style: style,
      dropdownColor: dropdownColor,
      menuMaxHeight: menuMaxHeight,
      borderRadius: borderRadius,
      alignment: alignment,
      enableFeedback: enableFeedback,
    );
  }

  static EdgeInsetsGeometry _bumpVerticalPadding(EdgeInsetsGeometry? padding) {
    final resolved = padding?.resolve(TextDirection.ltr) ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
    return EdgeInsets.fromLTRB(
      resolved.left,
      math.max(resolved.top, 16),
      resolved.right,
      math.max(resolved.bottom, 16),
    );
  }

  static Widget _wrapSelectedChild(Widget child) {
    return Align(
      alignment: Alignment.centerLeft,
      child: child,
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

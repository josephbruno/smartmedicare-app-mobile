import 'dart:async';
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
    // Keep top/bottom balanced so closed-button text stays vertically centered
    // under FloatingLabelBehavior.always.
    final vertical = math.max(resolved.top, resolved.bottom);
    return EdgeInsets.fromLTRB(
      resolved.left,
      math.max(vertical, 16),
      math.max(resolved.right, 8),
      math.max(vertical, 16),
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
    this.decoration,
    this.hint,
    this.asyncSearch,
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
  final InputDecoration? decoration;
  final String? hint;

  /// When set, typed queries also search remotely (full catalog), not only [options].
  final Future<List<AppSearchableOption<T>>> Function(String query)? asyncSearch;

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
        asyncSearch: asyncSearch,
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
    final base = decoration ?? InputDecoration(labelText: label);
    final resolvedPadding = base.contentPadding ?? themePadding;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openPicker(context),
      child: InputDecorator(
        isEmpty: text == null,
        decoration: base.copyWith(
          labelText: base.labelText ?? (decoration == null ? label : null),
          hintText: text == null ? (base.hintText ?? hint) : null,
          isDense: isDense,
          contentPadding:
              AppDropdownButtonFormField._contentPadding(resolvedPadding),
          suffixIcon: base.suffixIcon ??
              const Icon(Icons.search, size: 20),
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
  const AppSearchableOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
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
    this.asyncSearch,
  });

  final String title;
  final List<AppSearchableOption<T>> options;
  final T? selected;
  final String clearLabel;
  final bool allowClear;
  final String searchHint;
  final Future<List<AppSearchableOption<T>>> Function(String query)? asyncSearch;

  @override
  State<_SearchablePickerDialog<T>> createState() =>
      _SearchablePickerDialogState<T>();
}

class _SearchablePickerDialogState<T> extends State<_SearchablePickerDialog<T>> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  int _seq = 0;
  bool _searching = false;
  List<AppSearchableOption<T>>? _remote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<AppSearchableOption<T>> _localMatches(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return widget.options.where((o) {
      final hay = '${o.label} ${o.subtitle ?? ''}'.toLowerCase();
      return tokens.every((t) => hay.contains(t));
    }).toList(growable: false);
  }

  List<AppSearchableOption<T>> get _filtered {
    final local = _localMatches(_query.text);
    final remote = _remote;
    if (remote == null) return local;

    final seen = <T>{};
    final out = <AppSearchableOption<T>>[];
    for (final o in [...remote, ...local]) {
      if (seen.add(o.value)) out.add(o);
    }
    return out;
  }

  void _onQueryChanged(String raw) {
    setState(() {});
    _debounce?.cancel();
    if (widget.asyncSearch == null) return;

    final q = raw.trim();
    if (q.isEmpty) {
      _seq++;
      setState(() {
        _remote = null;
        _searching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 220), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final search = widget.asyncSearch;
    if (search == null) return;
    final seq = ++_seq;
    setState(() => _searching = true);
    try {
      final hits = await search(q);
      if (!mounted || seq != _seq) return;
      setState(() {
        _remote = hits;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final size = MediaQuery.sizeOf(context);
    final maxH = size.height * 0.55;
    final dialogW = math.min(520.0, size.width - 48);

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      content: SizedBox(
        width: dialogW,
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
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _query.clear();
                              _onQueryChanged('');
                            },
                          )),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        _searching ? 'Searching…' : 'No matches',
                        textAlign: TextAlign.center,
                      ),
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
                          title: Text(
                            o.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: (o.subtitle == null || o.subtitle!.isEmpty)
                              ? null
                              : Text(
                                  o.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
            if (filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} match${filtered.length == 1 ? '' : 'es'}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
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

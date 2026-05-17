import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';

/// Numeric form field tolerating both `,` and `.` decimal separators.
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.suffix,
    this.allowNull = false,
    this.min,
    this.max,
    this.allowDecimal = true,
    this.helpText,
  });

  final String label;
  final double? initialValue;
  final ValueChanged<double?> onChanged;
  final String? suffix;
  final bool allowNull;
  final double? min;
  final double? max;
  final bool allowDecimal;

  /// Optional in-context explanation rendered behind a help icon. When
  /// non-null a tooltip is attached to the field's suffix icon — used
  /// on technical fields whose label alone (e.g. "NOCT") isn't
  /// self-explanatory.
  final String? helpText;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue == null ? '' : _format(widget.initialValue!),
    );
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // When the field loses focus, force a revalidation pass so incomplete
    // values like "-" or "-0." are flagged as errors. While the field is
    // focused the validator suppresses these intermediate states (see below).
    if (!_focusNode.hasFocus) setState(() {});
  }

  @override
  void didUpdateWidget(NumberField old) {
    super.didUpdateWidget(old);
    if (old.initialValue != widget.initialValue) {
      final newText = widget.initialValue == null ? '' : _format(widget.initialValue!);
      if (_controller.text != newText) _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  String? _validate(String? raw) {
    final value = (raw ?? '').trim();
    final l = AppLocalizations.of(context);
    if (value.isEmpty) {
      if (widget.allowNull) return null;
      return l.validationRequired;
    }
    // Suppress errors for incomplete input only while the field has focus,
    // so typing "-0.4" doesn't flash errors on intermediate keystrokes.
    // _onFocusChange triggers a rebuild on blur so this guard is inactive
    // when the form is submitted or focus moves away.
    if (_focusNode.hasFocus &&
        (value == '-' || value.endsWith('.') || value.endsWith(','))) {
      return null;
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return l.validationMustBeNumber;
    if (widget.min != null && parsed < widget.min!) return l.validationAtLeast('${widget.min}');
    if (widget.max != null && parsed > widget.max!) return l.validationAtMost('${widget.max}');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pattern = widget.allowDecimal ? r'[0-9.,\-]' : r'[0-9\-]';
    // Mobile browsers render `numberWithOptions` as inputmode="decimal", which
    // omits the minus key even when signed:true. Use the text keyboard whenever
    // the field can hold a negative value so the "-" key is always reachable.
    // FilteringTextInputFormatter still restricts input to valid characters.
    final canBeNegative = widget.min == null || widget.min! < 0;
    final keyboardType = canBeNegative
        ? TextInputType.text
        : TextInputType.numberWithOptions(
            decimal: widget.allowDecimal, signed: false);
    final help = widget.helpText;
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: keyboardType,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(pattern))],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        isDense: true,
        suffixIcon: help == null
            ? null
            : Tooltip(
                message: help,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 6),
                child: const Icon(Icons.help_outline, size: 18),
              ),
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validate,
      onChanged: (raw) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          if (widget.allowNull) widget.onChanged(null);
          return;
        }
        final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
        if (parsed == null) return;
        // Don't poison the draft with out-of-range values that the user can
        // see flagged by the validator. The draft only sees values that the
        // engine would also accept.
        if (widget.min != null && parsed < widget.min!) return;
        if (widget.max != null && parsed > widget.max!) return;
        widget.onChanged(parsed);
      },
    );
  }
}

class IntField extends StatelessWidget {
  const IntField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.min,
    this.max,
    this.helpText,
  });

  final String label;
  final int initialValue;
  final ValueChanged<int> onChanged;
  final int? min;
  final int? max;
  final String? helpText;

  @override
  Widget build(BuildContext context) {
    return NumberField(
      label: label,
      initialValue: initialValue.toDouble(),
      min: min?.toDouble(),
      max: max?.toDouble(),
      allowDecimal: false,
      helpText: helpText,
      onChanged: (v) {
        if (v != null) onChanged(v.toInt());
      },
    );
  }
}

class StringField extends StatefulWidget {
  const StringField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.required = false,
    this.helpText,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool required;
  final String? helpText;

  @override
  State<StringField> createState() => _StringFieldState();
}

class _StringFieldState extends State<StringField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(StringField old) {
    super.didUpdateWidget(old);
    if (old.initialValue != widget.initialValue && _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final help = widget.helpText;
    final label = widget.required ? '${widget.label} *' : widget.label;
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        suffixIcon: help == null
            ? null
            : Tooltip(
                message: help,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 6),
                child: const Icon(Icons.help_outline, size: 18),
              ),
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) {
        if (widget.required && (v == null || v.trim().isEmpty)) {
          return AppLocalizations.of(context).validationRequired;
        }
        return null;
      },
      onChanged: widget.onChanged,
    );
  }
}

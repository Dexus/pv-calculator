import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

  final String label;
  final double? initialValue;
  final ValueChanged<double?> onChanged;
  final String? suffix;
  final bool allowNull;
  final double? min;
  final double? max;
  final bool allowDecimal;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue == null ? '' : _format(widget.initialValue!),
    );
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
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  String? _validate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      if (widget.allowNull) return null;
      return 'Pflichtfeld';
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Bitte eine Zahl eingeben';
    if (widget.min != null && parsed < widget.min!) return 'Mindestens ${widget.min}';
    if (widget.max != null && parsed > widget.max!) return 'Höchstens ${widget.max}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pattern = widget.allowDecimal ? r'[0-9.,\-]' : r'[0-9\-]';
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.allowDecimal, signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(pattern))],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        isDense: true,
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
  });

  final String label;
  final int initialValue;
  final ValueChanged<int> onChanged;
  final int? min;
  final int? max;

  @override
  Widget build(BuildContext context) {
    return NumberField(
      label: label,
      initialValue: initialValue.toDouble(),
      min: min?.toDouble(),
      max: max?.toDouble(),
      allowDecimal: false,
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
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool required;

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
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(labelText: widget.label, isDense: true),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) {
        if (widget.required && (v == null || v.trim().isEmpty)) return 'Pflichtfeld';
        return null;
      },
      onChanged: widget.onChanged,
    );
  }
}

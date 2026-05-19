import 'dart:math';

import 'package:component_catalog/component_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../catalog/catalog_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// Full-screen editor for a single user catalog entry.
///
/// Modes:
/// - **Create** (`initial: null`): id auto-fills from manufacturer/model
///   slug, collision dialog fires on save.
/// - **Edit** (`initial: nonNull`, `prefillOnly: false`): id locked,
///   collision dialog skipped (same-id upsert is the expected path).
/// - **Prefill-create** (`initial: nonNull`, `prefillOnly: true`): used
///   by the "duplicate seed" flow — initial values seed the form but
///   the id stays editable and the collision dialog still fires.
///
/// Returns the saved entry (or null on cancel) via `Navigator.pop`.
class CatalogEntryEditor extends StatefulWidget {
  const CatalogEntryEditor({
    super.key,
    required this.repository,
    required this.kind,
    this.initial,
    this.prefillOnly = false,
  });

  final CatalogRepository repository;
  final ComponentKind kind;
  final CatalogEntry? initial;

  /// When true, treat [initial] as form prefill data rather than an
  /// existing entry to edit. The id field stays editable and the
  /// collision dialog still fires on save.
  final bool prefillOnly;

  @override
  State<CatalogEntryEditor> createState() => _CatalogEntryEditorState();
}

class _CatalogEntryEditorState extends State<CatalogEntryEditor> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idCtrl;
  late final TextEditingController _manufacturerCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _sourceUrlCtrl;
  late final TextEditingController _notesCtrl;

  // Module
  late final TextEditingController _peakKwCtrl;
  late final TextEditingController _cellTechCtrl;
  late final TextEditingController _tempCoefCtrl;
  late final TextEditingController _noctCtrl;
  late final TextEditingController _degradationCtrl;

  // Inverter
  late final TextEditingController _maxAcKwCtrl;
  late final TextEditingController _maxDcKwCtrl;
  late final TextEditingController _efficiencyCtrl;
  late CatalogInverterRole _role;

  // Battery
  late final TextEditingController _capacityKwhCtrl;
  late final TextEditingController _chargeKwCtrl;
  late final TextEditingController _dischargeKwCtrl;
  late final TextEditingController _chemistryCtrl;
  late final TextEditingController _roundtripCtrl;
  late final TextEditingController _minSocCtrl;

  // Charge controller
  late final TextEditingController _ccEfficiencyCtrl;
  late final TextEditingController _ccMaxInputKwCtrl;
  late final TextEditingController _ccMaxOutputKwCtrl;
  late final TextEditingController _ccStandbyWCtrl;
  late final TextEditingController _ccMpptCountCtrl;

  // Shared optional unit price across all kinds; empty input means "unknown".
  late final TextEditingController _unitPriceCtrl;

  /// When true, the id field is overwritten from manufacturer/model on
  /// every keystroke. Flips to false on first manual edit of the id, or
  /// always-off when editing an existing entry.
  bool _idAutoFill = true;

  bool get _isEdit => widget.initial != null && !widget.prefillOnly;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _idCtrl = TextEditingController(text: initial?.id ?? '');
    _manufacturerCtrl = TextEditingController(text: initial?.manufacturer ?? '');
    _modelCtrl = TextEditingController(text: initial?.model ?? '');
    _sourceUrlCtrl = TextEditingController(text: initial?.sourceUrl ?? '');
    _notesCtrl = TextEditingController(text: initial?.notes ?? '');

    final m = initial is ModuleCatalogEntry ? initial : null;
    _peakKwCtrl = TextEditingController(
        text: m != null ? _fmt(m.peakKwPerModule) : '');
    _cellTechCtrl = TextEditingController(text: m?.cellTechnology ?? '');
    _tempCoefCtrl = TextEditingController(
        text: m != null ? _fmt(m.temperatureCoefficientPctPerC) : '0');
    _noctCtrl = TextEditingController(
        text: m != null ? _fmt(m.nominalOperatingCellTempC) : '45');
    _degradationCtrl = TextEditingController(
        text: m != null ? _fmt(m.degradationPctPerYear) : '0');

    final i = initial is InverterCatalogEntry ? initial : null;
    _maxAcKwCtrl =
        TextEditingController(text: i != null ? _fmt(i.maxAcKw) : '');
    _maxDcKwCtrl = TextEditingController(
        text: i?.maxDcInputKw != null ? _fmt(i!.maxDcInputKw!) : '');
    _efficiencyCtrl = TextEditingController(
        text: i != null ? _fmt(i.efficiency) : '0.965');
    _role = i?.role ?? CatalogInverterRole.grid;

    final b = initial is BatteryCatalogEntry ? initial : null;
    _capacityKwhCtrl =
        TextEditingController(text: b != null ? _fmt(b.capacityKwh) : '');
    _chargeKwCtrl =
        TextEditingController(text: b != null ? _fmt(b.maxChargeKw) : '');
    _dischargeKwCtrl =
        TextEditingController(text: b != null ? _fmt(b.maxDischargeKw) : '');
    _chemistryCtrl = TextEditingController(text: b?.chemistry ?? '');
    _roundtripCtrl = TextEditingController(
        text: b != null ? _fmt(b.roundTripEfficiency) : '0.9');
    _minSocCtrl =
        TextEditingController(text: b != null ? _fmt(b.minSocKwh) : '0');

    final c = initial is ChargeControllerCatalogEntry ? initial : null;
    _ccEfficiencyCtrl = TextEditingController(
        text: c != null ? _fmt(c.efficiency) : '0.97');
    _ccMaxInputKwCtrl = TextEditingController(
        text: c?.maxInputKw != null ? _fmt(c!.maxInputKw!) : '');
    _ccMaxOutputKwCtrl = TextEditingController(
        text: c?.maxOutputKw != null ? _fmt(c!.maxOutputKw!) : '');
    _ccStandbyWCtrl = TextEditingController(
        text: c != null ? _fmt(c.standbyW) : '0');
    _ccMpptCountCtrl = TextEditingController(
        text: c?.mpptCount != null ? c!.mpptCount!.toString() : '');

    _unitPriceCtrl = TextEditingController(
        text: initial?.unitPriceEur != null ? _fmt(initial!.unitPriceEur!) : '');

    _idAutoFill = !_isEdit && _idCtrl.text.isEmpty;
    _manufacturerCtrl.addListener(_maybeAutoFillId);
    _modelCtrl.addListener(_maybeAutoFillId);
  }

  @override
  void dispose() {
    _manufacturerCtrl.removeListener(_maybeAutoFillId);
    _modelCtrl.removeListener(_maybeAutoFillId);
    for (final c in [
      _idCtrl,
      _manufacturerCtrl,
      _modelCtrl,
      _sourceUrlCtrl,
      _notesCtrl,
      _peakKwCtrl,
      _cellTechCtrl,
      _tempCoefCtrl,
      _noctCtrl,
      _degradationCtrl,
      _maxAcKwCtrl,
      _maxDcKwCtrl,
      _efficiencyCtrl,
      _capacityKwhCtrl,
      _chargeKwCtrl,
      _dischargeKwCtrl,
      _chemistryCtrl,
      _roundtripCtrl,
      _minSocCtrl,
      _ccEfficiencyCtrl,
      _ccMaxInputKwCtrl,
      _ccMaxOutputKwCtrl,
      _ccStandbyWCtrl,
      _ccMpptCountCtrl,
      _unitPriceCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _maybeAutoFillId() {
    if (!_idAutoFill) return;
    final slug = slugifyForCatalogId(
        '${_manufacturerCtrl.text} ${_modelCtrl.text}');
    _idCtrl.text = slug;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = _isEdit
        ? l.catalogEditorTitleEdit(widget.initial!.displayName)
        : switch (widget.kind) {
            ComponentKind.module => l.catalogEditorTitleNewModule,
            ComponentKind.inverter => l.catalogEditorTitleNewInverter,
            ComponentKind.battery => l.catalogEditorTitleNewBattery,
            ComponentKind.chargeController =>
              l.catalogEditorTitleNewChargeController,
          };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            key: const Key('catalog-editor-save'),
            onPressed: _onSave,
            // Inherit the AppBar's foreground color. The Material 3 AppBar
            // uses `surface` (not `primary`) as its background, so forcing
            // onPrimary would make the button invisible in default themes.
            child: Text(l.catalogEditorSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _stringField(
              key: const Key('catalog-editor-manufacturer'),
              controller: _manufacturerCtrl,
              label: l.catalogEditorFieldManufacturer,
              required: true,
              localizations: l,
            ),
            const SizedBox(height: 12),
            _stringField(
              key: const Key('catalog-editor-model'),
              controller: _modelCtrl,
              label: l.catalogEditorFieldModel,
              required: true,
              localizations: l,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('catalog-editor-id'),
              controller: _idCtrl,
              enabled: !_isEdit,
              decoration: InputDecoration(
                labelText: l.catalogEditorFieldId,
                helperText: l.catalogEditorFieldIdHelp,
              ),
              onChanged: (_) {
                if (_idAutoFill) setState(() => _idAutoFill = false);
              },
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.validationRequired : null,
            ),
            const SizedBox(height: 12),
            _stringField(
              controller: _sourceUrlCtrl,
              label: l.catalogEditorFieldSourceUrl,
              required: false,
              localizations: l,
            ),
            const SizedBox(height: 12),
            _stringField(
              controller: _notesCtrl,
              label: l.catalogEditorFieldNotes,
              required: false,
              localizations: l,
              maxLines: 3,
            ),
            const Divider(height: 32),
            ..._kindFields(l),
          ],
        ),
      ),
    );
  }

  List<Widget> _kindFields(AppLocalizations l) {
    switch (widget.kind) {
      case ComponentKind.module:
        return [
          _numberField(
            key: const Key('catalog-editor-peak-kw'),
            controller: _peakKwCtrl,
            label: l.catalogEditorFieldPeakKwPerModule,
            required: true,
            min: 1e-6,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _stringField(
            controller: _cellTechCtrl,
            label: l.catalogEditorFieldCellTech,
            required: false,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _tempCoefCtrl,
            label: l.catalogEditorFieldTempCoef,
            required: true,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _noctCtrl,
            label: l.catalogEditorFieldNoct,
            required: true,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _degradationCtrl,
            label: l.catalogEditorFieldDegradation,
            required: true,
            min: 0,
            max: 10,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _unitPriceField(l, l.catalogEditorFieldUnitPriceHelpModule),
        ];
      case ComponentKind.inverter:
        return [
          _numberField(
            key: const Key('catalog-editor-max-ac-kw'),
            controller: _maxAcKwCtrl,
            label: l.catalogEditorFieldMaxAcKw,
            required: true,
            min: 1e-6,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _maxDcKwCtrl,
            label: l.catalogEditorFieldMaxDcKw,
            required: false,
            min: 1e-6,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _efficiencyCtrl,
            label: l.catalogEditorFieldEfficiency,
            required: true,
            min: 1e-6,
            max: 1,
            localizations: l,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CatalogInverterRole>(
            key: const Key('catalog-editor-role'),
            initialValue: _role,
            decoration: InputDecoration(labelText: l.catalogEditorFieldRole),
            items: [
              DropdownMenuItem(
                value: CatalogInverterRole.grid,
                child: Text(l.catalogRoleGrid),
              ),
              DropdownMenuItem(
                value: CatalogInverterRole.batteryCoupled,
                child: Text(l.catalogRoleBattery),
              ),
              DropdownMenuItem(
                value: CatalogInverterRole.microInverter800W,
                child: Text(l.catalogRoleMicro),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _role = v);
            },
          ),
          const SizedBox(height: 12),
          _unitPriceField(l, l.catalogEditorFieldUnitPriceHelpInverter),
        ];
      case ComponentKind.battery:
        return [
          _numberField(
            key: const Key('catalog-editor-capacity-kwh'),
            controller: _capacityKwhCtrl,
            label: l.catalogEditorFieldCapacityKwh,
            required: true,
            min: 1e-6,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _chargeKwCtrl,
            label: l.catalogEditorFieldChargeKw,
            required: true,
            min: 1e-6,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _dischargeKwCtrl,
            label: l.catalogEditorFieldDischargeKw,
            required: true,
            min: 1e-6,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _stringField(
            controller: _chemistryCtrl,
            label: l.catalogEditorFieldChemistry,
            required: false,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _roundtripCtrl,
            label: l.catalogEditorFieldRoundtrip,
            required: true,
            min: 1e-6,
            max: 1,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _minSocCtrl,
            label: l.catalogEditorFieldMinSoc,
            required: true,
            min: 0,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _unitPriceField(l, l.catalogEditorFieldUnitPriceHelpBattery),
        ];
      case ComponentKind.chargeController:
        return [
          _numberField(
            key: const Key('catalog-editor-cc-efficiency'),
            controller: _ccEfficiencyCtrl,
            label: l.catalogEditorFieldCcEfficiency,
            required: true,
            min: 1e-6,
            max: 1,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            key: const Key('catalog-editor-cc-max-input-kw'),
            controller: _ccMaxInputKwCtrl,
            label: l.catalogEditorFieldCcMaxInputKw,
            required: false,
            min: 1e-6,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            key: const Key('catalog-editor-cc-max-output-kw'),
            controller: _ccMaxOutputKwCtrl,
            label: l.catalogEditorFieldCcMaxOutputKw,
            required: false,
            min: 1e-6,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            key: const Key('catalog-editor-cc-standby-w'),
            controller: _ccStandbyWCtrl,
            label: l.catalogEditorFieldCcStandbyW,
            required: true,
            min: 0,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _numberField(
            key: const Key('catalog-editor-cc-mppt-count'),
            controller: _ccMpptCountCtrl,
            label: l.catalogEditorFieldCcMpptCount,
            required: false,
            min: 1,
            integerOnly: true,
            localizations: l,
          ),
          const SizedBox(height: 12),
          _unitPriceField(
              l, l.catalogEditorFieldUnitPriceHelpChargeController),
        ];
    }
  }

  Widget _stringField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required bool required,
    required AppLocalizations localizations,
    int maxLines = 1,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      maxLines: maxLines,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
              ? localizations.validationRequired
              : null
          : null,
    );
  }

  Widget _numberField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required bool required,
    required AppLocalizations localizations,
    double? min,
    double? max,
    bool integerOnly = false,
  }) {
    // Mirror the shared `NumberField`'s keyboard choice: mobile browsers
    // strip the minus key from inputmode=decimal even with signed:true,
    // so the text keyboard is the only reliable way to type negatives.
    final canBeNegative = min == null || min < 0;
    final keyboardType = canBeNegative && !integerOnly
        ? TextInputType.text
        : TextInputType.numberWithOptions(
            decimal: !integerOnly, signed: false);
    // Digit-only formatter for integer fields prevents `1.5` / `1,0` from
    // ever reaching the controller, so the save-time `int.parse` cannot
    // throw a late `FormatException`.
    final allowed = integerOnly ? RegExp(r'[0-9]') : RegExp(r'[0-9.,\-]');
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: [
        FilteringTextInputFormatter.allow(allowed),
      ],
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) {
          return required ? localizations.validationRequired : null;
        }
        if (!integerOnly &&
            (text == '-' || text.endsWith('.') || text.endsWith(','))) {
          // Suppress errors for in-progress decimal input. The form's
          // final validate() pass on save will still catch genuinely
          // invalid input.
          return null;
        }
        final double? parsed;
        if (integerOnly) {
          parsed = int.tryParse(text)?.toDouble();
        } else {
          parsed = double.tryParse(text.replaceAll(',', '.'));
        }
        if (parsed == null || !parsed.isFinite) {
          return localizations.validationMustBeNumber;
        }
        if (min != null && parsed < min) {
          return localizations.validationAtLeast(_fmt(min));
        }
        if (max != null && parsed > max) {
          return localizations.validationAtMost(_fmt(max));
        }
        return null;
      },
    );
  }

  Widget _unitPriceField(AppLocalizations l, String helperText) {
    // The same shared field across module/inverter/battery; helper text
    // disambiguates "per what" since the unit differs by kind. Optional
    // — empty input round-trips to `unitPriceEur: null`.
    return TextFormField(
      key: const Key('catalog-editor-unit-price'),
      controller: _unitPriceCtrl,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: l.catalogEditorFieldUnitPrice,
        helperText: helperText,
      ),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return null;
        if (text.endsWith('.') || text.endsWith(',')) return null;
        final parsed = double.tryParse(text.replaceAll(',', '.'));
        if (parsed == null || !parsed.isFinite) {
          return l.validationMustBeNumber;
        }
        if (parsed < 0) return l.validationAtLeast('0');
        return null;
      },
    );
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = AppLocalizations.of(context);
    final CatalogEntry entry;
    try {
      // _buildEntry's double.parse calls can still throw FormatException
      // for in-progress input ('-', '0.') that the per-field validator
      // intentionally lets through to avoid flicker on every keystroke.
      entry = _buildEntry();
      entry.validate();
    } on ArgumentError catch (e) {
      _showSnack(l.catalogEditorValidationFailed('${e.message ?? e}'));
      return;
    } on FormatException catch (e) {
      _showSnack(l.catalogEditorValidationFailed(e.message));
      return;
    }

    if (!_isEdit) {
      final users = await widget.repository.userEntries();
      final exists = users.any((u) => u.id == entry.id);
      if (exists) {
        if (!mounted) return;
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.catalogEditorIdConflictTitle),
            content: Text(l.catalogEditorIdConflictBody(entry.id)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                key: const Key('catalog-editor-id-conflict-overwrite'),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l.catalogEditorIdConflictOverwrite),
              ),
            ],
          ),
        );
        if (overwrite != true) return;
      }
    }

    try {
      await widget.repository.addUserEntry(entry);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      _showSnack(l.catalogEditorValidationFailed('${e.message ?? e}'));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(entry);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  CatalogEntry _buildEntry() {
    final id = _idCtrl.text.trim();
    final manufacturer = _manufacturerCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final sourceUrl = _emptyToNull(_sourceUrlCtrl.text);
    final notes = _emptyToNull(_notesCtrl.text);
    final unitPriceEur = _parseOptional(_unitPriceCtrl.text);
    switch (widget.kind) {
      case ComponentKind.module:
        return ModuleCatalogEntry(
          id: id,
          manufacturer: manufacturer,
          model: model,
          peakKwPerModule: _parse(_peakKwCtrl.text),
          cellTechnology: _emptyToNull(_cellTechCtrl.text),
          temperatureCoefficientPctPerC: _parse(_tempCoefCtrl.text),
          nominalOperatingCellTempC: _parse(_noctCtrl.text),
          degradationPctPerYear: _parse(_degradationCtrl.text),
          sourceUrl: sourceUrl,
          notes: notes,
          unitPriceEur: unitPriceEur,
        );
      case ComponentKind.inverter:
        return InverterCatalogEntry(
          id: id,
          manufacturer: manufacturer,
          model: model,
          maxAcKw: _parse(_maxAcKwCtrl.text),
          maxDcInputKw: _parseOptional(_maxDcKwCtrl.text),
          efficiency: _parse(_efficiencyCtrl.text),
          role: _role,
          sourceUrl: sourceUrl,
          notes: notes,
          unitPriceEur: unitPriceEur,
        );
      case ComponentKind.battery:
        return BatteryCatalogEntry(
          id: id,
          manufacturer: manufacturer,
          model: model,
          capacityKwh: _parse(_capacityKwhCtrl.text),
          maxChargeKw: _parse(_chargeKwCtrl.text),
          maxDischargeKw: _parse(_dischargeKwCtrl.text),
          chemistry: _emptyToNull(_chemistryCtrl.text),
          roundTripEfficiency: _parse(_roundtripCtrl.text),
          minSocKwh: _parse(_minSocCtrl.text),
          sourceUrl: sourceUrl,
          notes: notes,
          unitPriceEur: unitPriceEur,
        );
      case ComponentKind.chargeController:
        return ChargeControllerCatalogEntry(
          id: id,
          manufacturer: manufacturer,
          model: model,
          efficiency: _parse(_ccEfficiencyCtrl.text),
          maxInputKw: _parseOptional(_ccMaxInputKwCtrl.text),
          maxOutputKw: _parseOptional(_ccMaxOutputKwCtrl.text),
          standbyW: _parse(_ccStandbyWCtrl.text),
          mpptCount: _parseOptionalInt(_ccMpptCountCtrl.text),
          sourceUrl: sourceUrl,
          notes: notes,
          unitPriceEur: unitPriceEur,
        );
    }
  }
}

int? _parseOptionalInt(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : int.parse(trimmed);
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double _parse(String text) =>
    double.parse(text.trim().replaceAll(',', '.'));

double? _parseOptional(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : double.parse(trimmed.replaceAll(',', '.'));
}

String _fmt(double v) {
  if (v == v.truncate().toDouble()) return v.toStringAsFixed(0);
  return v.toString();
}

/// Lowercases [input], folds German umlauts/ß to ASCII, replaces every
/// other non-alphanumeric run with a single `-`, and trims leading and
/// trailing dashes. Used to suggest catalog ids from
/// manufacturer/model strings. Pure for testability.
String slugifyForCatalogId(String input) {
  final lower = input.toLowerCase().trim();
  final ascii = lower
      .replaceAll(RegExp(r'[ä]'), 'ae')
      .replaceAll(RegExp(r'[ö]'), 'oe')
      .replaceAll(RegExp(r'[ü]'), 'ue')
      .replaceAll('ß', 'ss');
  return ascii
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Appends a short pseudo-random suffix to disambiguate seed→user-copy
/// ids. Not cryptographically strong; collision probability across the
/// few-thousand-entry expected scale is negligible.
String addCollisionSuffix(String slug) {
  final r = Random();
  final suffix = r.nextInt(0xFFFFFF).toRadixString(36).padLeft(4, '0');
  return slug.isEmpty ? suffix : '$slug-$suffix';
}

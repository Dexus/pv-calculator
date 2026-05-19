import 'package:component_catalog/component_catalog.dart';

import '../../l10n/generated/app_localizations.dart';

/// Builds the short subtitle string used by both the catalog picker
/// sheet and the catalog management page (module wattage, inverter AC
/// rating + role, battery capacity + charge rates). When the entry
/// declares a price it is appended as a trailing ` · {price} €/…`
/// segment so users can compare list prices in the picker.
String summariseCatalogEntry(CatalogEntry e, AppLocalizations l) {
  final priceSuffix = _priceSuffix(e, l);
  if (e is ModuleCatalogEntry) {
    final w = (e.peakKwPerModule * 1000).toStringAsFixed(0);
    final tech = e.cellTechnology != null ? ' · ${e.cellTechnology}' : '';
    return '$w W$tech$priceSuffix';
  }
  if (e is InverterCatalogEntry) {
    return '${e.maxAcKw.toStringAsFixed(1)} kW AC · '
        '${catalogRoleLabel(e.role, l)}$priceSuffix';
  }
  if (e is BatteryCatalogEntry) {
    final chem = e.chemistry != null ? ' · ${e.chemistry}' : '';
    return '${e.capacityKwh.toStringAsFixed(1)} kWh · '
        '${e.maxChargeKw.toStringAsFixed(1)}/${e.maxDischargeKw.toStringAsFixed(1)} kW'
        '$chem$priceSuffix';
  }
  return '';
}

String _priceSuffix(CatalogEntry e, AppLocalizations l) {
  final price = e.unitPriceEur;
  if (price == null) return '';
  final formatted = _formatPriceEur(price);
  final label = switch (e) {
    ModuleCatalogEntry _ => l.catalogSummaryUnitPriceModule(formatted),
    InverterCatalogEntry _ => l.catalogSummaryUnitPriceInverter(formatted),
    BatteryCatalogEntry _ => l.catalogSummaryUnitPriceBattery(formatted),
    _ => '',
  };
  return label.isEmpty ? '' : ' · $label';
}

String _formatPriceEur(double v) {
  // Integer prices (the common case for €) render without a decimal tail.
  if (v == v.truncate().toDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

String catalogRoleLabel(CatalogInverterRole r, AppLocalizations l) =>
    switch (r) {
      CatalogInverterRole.grid => l.catalogRoleGrid,
      CatalogInverterRole.batteryCoupled => l.catalogRoleBattery,
      CatalogInverterRole.microInverter800W => l.catalogRoleMicro,
    };

import 'package:component_catalog/component_catalog.dart';

import '../../l10n/generated/app_localizations.dart';

/// Builds the short subtitle string used by both the catalog picker
/// sheet and the catalog management page (module wattage, inverter AC
/// rating + role, battery capacity + charge rates).
String summariseCatalogEntry(CatalogEntry e, AppLocalizations l) {
  if (e is ModuleCatalogEntry) {
    final w = (e.peakKwPerModule * 1000).toStringAsFixed(0);
    final tech = e.cellTechnology != null ? ' · ${e.cellTechnology}' : '';
    return '$w W$tech';
  }
  if (e is InverterCatalogEntry) {
    return '${e.maxAcKw.toStringAsFixed(1)} kW AC · ${catalogRoleLabel(e.role, l)}';
  }
  if (e is BatteryCatalogEntry) {
    final chem = e.chemistry != null ? ' · ${e.chemistry}' : '';
    return '${e.capacityKwh.toStringAsFixed(1)} kWh · '
        '${e.maxChargeKw.toStringAsFixed(1)}/${e.maxDischargeKw.toStringAsFixed(1)} kW$chem';
  }
  return '';
}

String catalogRoleLabel(CatalogInverterRole r, AppLocalizations l) =>
    switch (r) {
      CatalogInverterRole.grid => l.catalogRoleGrid,
      CatalogInverterRole.batteryCoupled => l.catalogRoleBattery,
      CatalogInverterRole.microInverter800W => l.catalogRoleMicro,
    };

import '../l10n/generated/app_localizations.dart';
import 'config_draft.dart';

/// Localizes a [ValidationWarning] to the user-facing message string
/// used by both the Auswertung-tab warnings card and the PDF report.
/// Mapped here (rather than in each renderer) so the two surfaces
/// stay in sync — adding a new warning code only needs one switch.
String localizeValidationWarning(AppLocalizations l, ValidationWarning w) {
  switch (w.code) {
    case 'inverter-oversized':
      return l.warningInverterOversized(
          w.args['inverter'] ?? '', w.args['ratio'] ?? '');
    case 'bank-exceeds-discharge':
      return l.warningBankExceedsDischarge(
          w.args['bank'] ?? '',
          w.args['bankKw'] ?? '',
          w.args['dischargeKw'] ?? '');
    case 'battery-min-soc-high':
      return l.warningBatteryMinSocHigh(
          w.args['battery'] ?? '', w.args['pct'] ?? '');
    case 'irradiance-missing':
      return l.hintIrradianceMissing;
  }
  return w.code;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/project_controller.dart';
import '_field.dart';

/// Tariff editor — flat €/kWh import and export prices (Free) plus a
/// 24-slot time-of-use grid (Pro). Hidden behind a master enable
/// toggle so projects that don't care about economics stay zero-cost
/// at engine level.
class TariffSection extends StatelessWidget {
  const TariffSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<ProjectController>();
    final tariff = controller.draft.tariff;

    return Card(
      child: ExpansionTile(
        key: const Key('tariff-section'),
        title: Text(l.tariffSectionTitle),
        leading: const Icon(Icons.payments_outlined),
        initiallyExpanded: tariff.enabled,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchListTile(
                key: const Key('tariff-enabled-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.tariffEnabled),
                subtitle: Text(l.tariffEnabledHelp),
                value: tariff.enabled,
                onChanged: (v) {
                  tariff.enabled = v;
                  controller.touch();
                },
              ),
              if (tariff.enabled) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(width: 200, child: NumberField(
                    key: const Key('tariff-import-flat'),
                    label: l.tariffImportLabel,
                    suffix: 'EUR/kWh',
                    initialValue: tariff.importPricePerKwh,
                    min: 0,
                    onChanged: (v) {
                      if (v != null) {
                        tariff.importPricePerKwh = v;
                        controller.touch();
                      }
                    },
                  )),
                  SizedBox(width: 200, child: NumberField(
                    key: const Key('tariff-export-flat'),
                    label: l.tariffExportLabel,
                    suffix: 'EUR/kWh',
                    initialValue: tariff.exportPricePerKwh,
                    min: 0,
                    onChanged: (v) {
                      if (v != null) {
                        tariff.exportPricePerKwh = v;
                        controller.touch();
                      }
                    },
                  )),
                ]),
                const SizedBox(height: 16),
                SwitchListTile(
                  key: const Key('tariff-tou-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(kProFeatures
                      ? l.tariffTouTitle
                      : '${l.tariffTouTitle} (Pro)'),
                  subtitle: Text(l.tariffTouHelp),
                  value: tariff.touEnabled && kProFeatures,
                  onChanged: kProFeatures
                      ? (v) {
                          tariff.touEnabled = v;
                          controller.touch();
                        }
                      : null,
                ),
                if (tariff.touEnabled && kProFeatures) ...[
                  const SizedBox(height: 8),
                  Text(l.tariffTouImportHeader,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  _HourlyGrid(
                    keyPrefix: 'tariff-tou-import',
                    values: tariff.hourlyImportPrices,
                    onChanged: () => controller.touch(),
                  ),
                  const SizedBox(height: 12),
                  Text(l.tariffTouExportHeader,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  _HourlyGrid(
                    keyPrefix: 'tariff-tou-export',
                    values: tariff.hourlyExportPrices,
                    onChanged: () => controller.touch(),
                  ),
                ],
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _HourlyGrid extends StatelessWidget {
  const _HourlyGrid({
    required this.keyPrefix,
    required this.values,
    required this.onChanged,
  });

  final String keyPrefix;
  final List<double> values;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < 24; i++)
        SizedBox(
          width: 90,
          child: NumberField(
            key: Key('$keyPrefix-$i'),
            label: '${i.toString().padLeft(2, '0')} h',
            initialValue: values[i],
            min: 0,
            onChanged: (v) {
              if (v != null) {
                values[i] = v;
                onChanged();
              }
            },
          ),
        ),
    ]);
  }
}

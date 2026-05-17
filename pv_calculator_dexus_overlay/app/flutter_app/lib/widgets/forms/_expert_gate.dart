import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';

/// Wraps advanced editor sections (topology, micro-inverter banks,
/// alternative dispatch policies) so they only render when the user
/// has opted into expert mode. Default is off — PRD R-04 mitigation
/// ("Topologie-Editor kann Nutzer überfordern").
class ExpertOnly extends StatelessWidget {
  const ExpertOnly({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final expert = context.watch<SettingsController>().expertMode;
    if (!expert) return const SizedBox.shrink();
    return child;
  }
}

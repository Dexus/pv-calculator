import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: RadioGroup<ThemeMode>(
        groupValue: settings.themeMode,
        onChanged: (mode) {
          if (mode != null) settings.setThemeMode(mode);
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Erscheinungsbild',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const RadioListTile<ThemeMode>(
              key: Key('theme-mode-system'),
              title: Text('Systemvorgabe folgen'),
              subtitle: Text('Wechselt mit der Geräteeinstellung.'),
              value: ThemeMode.system,
            ),
            const RadioListTile<ThemeMode>(
              key: Key('theme-mode-light'),
              title: Text('Hell'),
              value: ThemeMode.light,
            ),
            const RadioListTile<ThemeMode>(
              key: Key('theme-mode-dark'),
              title: Text('Dunkel'),
              value: ThemeMode.dark,
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Über die App'),
              onTap: () => showAppAboutDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

void showAppAboutDialog(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'PV Calculator',
    applicationVersion: '0.1.0',
    applicationLegalese: '© Dexus — AGPL-3.0',
    children: const [
      SizedBox(height: 12),
      Text(
        'Demo-Anwendung zur PV-Auslegung mit Batteriespeicher und '
        '800-W-Micro-Wechselrichter. Das aktuelle Strahlungsmodell ist '
        'synthetisch und stellt keine validierte Ertragsprognose dar.',
      ),
    ],
  );
}

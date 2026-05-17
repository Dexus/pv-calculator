import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'settings_page.dart';

/// Navigation drawer attached to top-level pages (currently only the
/// project list). Forward-navigation pages — editor, results — intentionally
/// keep the back arrow instead of the hamburger so users don't lose
/// unsaved edits by jumping sideways.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: scheme.primaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.solar_power, size: 40, color: scheme.onPrimaryContainer),
                  const SizedBox(height: 8),
                  Text(
                    'PV Calculator',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                  Text(
                    l.drawerSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(l.drawerProjects),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              key: const Key('drawer-settings'),
              leading: const Icon(Icons.settings_outlined),
              title: Text(l.drawerSettings),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              key: const Key('drawer-about'),
              leading: const Icon(Icons.info_outline),
              title: Text(l.drawerAbout),
              onTap: () {
                Navigator.pop(context);
                showAppAboutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

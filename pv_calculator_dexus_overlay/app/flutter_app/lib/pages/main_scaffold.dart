import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/project_controller.dart';
import '../widgets/app_drawer.dart';
import 'arrays_tab.dart';
import 'irradiance_tab.dart';
import 'projects_tab.dart';
import 'results_tab.dart';

/// Top-level scaffold for the redesigned app. Hosts the four tabs the
/// screenshots define: project list (folder icon), Einstrahlung, PV-Arrays,
/// Auswertung. The compass overlay on the Einstrahlung tab writes back
/// to whichever array is selected on the PV-Arrays tab; that selection
/// state lives on [ProjectController.selectedArrayIndex].
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<ProjectController>();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: Text(controller.projectName),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.folder_open), text: l.tabProjects),
              Tab(text: l.tabIrradiance),
              Tab(text: l.tabArrays),
              Tab(text: l.tabResults),
            ],
          ),
        ),
        body: const TabBarView(
          // Disabling swipe keeps the map's pan gesture from competing
          // with the tab controller on the Einstrahlung tab. Tabs are
          // still tappable in the bar above.
          physics: NeverScrollableScrollPhysics(),
          children: [
            ProjectsTab(),
            IrradianceTab(),
            ArraysTab(),
            ResultsTab(),
          ],
        ),
      ),
    );
  }
}

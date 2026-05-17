import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../persistence/file_io.dart';
import '../persistence/models.dart';
import '../persistence/project_repository.dart';
import '../persistence/scenario_repository.dart';
import '../state/config_draft.dart';
import '../state/project_controller.dart';
import '../state/scenario_comparison_controller.dart';
import 'scenario_compare_page.dart';

/// Phase-7 projects tab: relational project ▸ scenarios tree backed by
/// `ProjectRepository` / `ScenarioRepository`. Replaces the flat
/// shared_preferences list — existing SP projects are migrated into the
/// new schema once on startup by `SharedPreferencesMigration` and never
/// reappear here directly.
class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key, this.fileIo});

  /// Injection point for widget tests; production uses the default.
  final FileIo? fileIo;

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  late final FileIo _fileIo = widget.fileIo ?? const FileIo();
  late ProjectRepository _projects;
  late ScenarioRepository _scenarios;

  final Set<String> _compareIds = <String>{};
  late List<ProjectRow> _projectList = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _projects = context.read<ProjectRepository>();
    _scenarios = context.read<ScenarioRepository>();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _projectList = _projects.listProjects();
      // Drop ids that no longer exist (e.g. after a delete) from the
      // compare selection so the badge count stays honest.
      final liveIds = <String>{
        for (final p in _projectList)
          ..._scenarios.listForProject(p.id).map((s) => s.id),
      };
      _compareIds.removeWhere((id) => !liveIds.contains(id));
    });
  }

  Future<void> _newProject() async {
    final l = AppLocalizations.of(context);
    final existing = _projectList.map((p) => p.name).toSet();
    final name = _uniqueName(l.projectListNewDefaultName, existing);
    final project = _projects.createProject(name: name);
    final config = ConfigDraft.demo().build();
    final scenario = _scenarios.create(
      projectId: project.id,
      siteId: _projects.defaultSiteFor(project.id)?.id,
      name: 'Default',
      config: config,
    );
    _refresh();
    if (!mounted) return;
    _openScenario(project, scenario);
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final imported = await _fileIo.importConfig();
      if (imported == null || !mounted) return;
      var name = imported.suggestedName;
      final taken = _projectList.map((p) => p.name).toSet();
      if (taken.contains(name)) {
        name = _uniqueName(name, taken);
      }
      final project = _projects.createProject(name: name);
      _scenarios.create(
        projectId: project.id,
        siteId: _projects.defaultSiteFor(project.id)?.id,
        name: 'Default',
        config: imported.config,
      );
      _refresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.projectListImported(name))));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.projectListImportFailed(e.toString()))));
    }
  }

  Future<void> _saveCurrent() async {
    final controller = context.read<ProjectController>();
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final config = controller.draft.build();
    try {
      final id = controller.scenarioId;
      if (id == null) {
        // Save-as: build a new project + scenario named after the
        // controller's current `projectName` field. Matches the pre-
        // Phase-7 behaviour where Save Current implicitly created an
        // entry.
        var name = controller.projectName.trim();
        if (name.isEmpty) name = l.projectListNewDefaultName;
        final taken = _projectList.map((p) => p.name).toSet();
        if (taken.contains(name)) name = _uniqueName(name, taken);
        final project = _projects.createProject(name: name);
        final scenario = _scenarios.create(
          projectId: project.id,
          siteId: _projects.defaultSiteFor(project.id)?.id,
          name: 'Default',
          config: config,
        );
        controller.loadDraft(
          project.name,
          ConfigDraft.fromConfig(scenario.config),
          scenarioId: scenario.id,
          projectId: project.id,
        );
      } else {
        _scenarios.update(id, config: config);
      }
      _refresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.projectListExported(controller.projectName))));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.projectListSaveFailed(e.toString()))));
    }
  }

  void _openScenario(ProjectRow project, ScenarioRow scenario) {
    final controller = context.read<ProjectController>();
    controller.loadDraft(
      project.name,
      ConfigDraft.fromConfig(scenario.config),
      scenarioId: scenario.id,
      projectId: project.id,
    );
    DefaultTabController.of(context).animateTo(1);
  }

  Future<void> _renameProject(ProjectRow project) async {
    final l = AppLocalizations.of(context);
    final name = await _promptText(
      title: l.projectsTabRenameProjectTitle,
      initial: project.name,
      cancel: l.commonCancel,
      ok: l.projectsTabDialogSave,
    );
    if (name == null || name.trim().isEmpty || name == project.name) return;
    _projects.renameProject(project.id, name.trim());
    _refresh();
  }

  Future<void> _deleteProject(ProjectRow project) async {
    final l = AppLocalizations.of(context);
    // Capture the controller before the await so we don't reach back into
    // `context` once the confirm dialog returns (the host widget could
    // have been disposed in the meantime).
    final controller = context.read<ProjectController>();
    final ok = await _confirm(
      title: l.projectListDeleteTitle,
      body: l.projectListDeleteBody(project.name),
      ok: l.commonDelete,
      cancel: l.commonCancel,
    );
    if (!ok) return;
    // Cascade deletes the scenarios too, so any of them that the editor is
    // currently holding is about to disappear. Reset the controller to an
    // unsaved demo draft before the row goes away — otherwise the editor
    // keeps a stale (projectId, scenarioId) and the next Save Current
    // tries to UPDATE a deleted row, which throws inside `findById(id)!`.
    if (controller.projectId == project.id) {
      _resetActiveDraft(controller, l);
    }
    _projects.deleteProject(project.id);
    _refresh();
  }

  Future<void> _newScenario(ProjectRow project) async {
    final l = AppLocalizations.of(context);
    final siblings = _scenarios.listForProject(project.id).map((s) => s.name).toSet();
    final name = await _promptText(
      title: l.projectsTabNewScenarioTitle,
      initial: _uniqueName(l.projectsTabSuggestedScenarioName, siblings),
      cancel: l.commonCancel,
      ok: l.projectsTabDialogCreate,
    );
    if (name == null || name.trim().isEmpty) return;
    final scenario = _scenarios.create(
      projectId: project.id,
      siteId: _projects.defaultSiteFor(project.id)?.id,
      name: name.trim(),
      config: ConfigDraft.demo().build(),
    );
    _refresh();
    if (!mounted) return;
    _openScenario(project, scenario);
  }

  Future<void> _duplicateScenario(ScenarioRow scenario) async {
    _scenarios.duplicate(scenario.id);
    _refresh();
  }

  Future<void> _renameScenario(ScenarioRow scenario) async {
    final l = AppLocalizations.of(context);
    final name = await _promptText(
      title: l.projectsTabRenameScenarioTitle,
      initial: scenario.name,
      cancel: l.commonCancel,
      ok: l.projectsTabDialogSave,
    );
    if (name == null || name.trim().isEmpty || name == scenario.name) return;
    _scenarios.rename(scenario.id, name.trim());
    _refresh();
  }

  Future<void> _deleteScenario(ScenarioRow scenario) async {
    final l = AppLocalizations.of(context);
    final controller = context.read<ProjectController>();
    final ok = await _confirm(
      title: l.projectsTabDeleteScenarioTitle,
      body: l.projectsTabDeleteScenarioBody(scenario.name),
      ok: l.commonDelete,
      cancel: l.commonCancel,
    );
    if (!ok) return;
    // Same Save-Current trap as _deleteProject: if the editor is holding
    // this scenario, swap it for an unsaved demo draft before the row
    // disappears.
    if (controller.scenarioId == scenario.id) {
      _resetActiveDraft(controller, l);
    }
    _scenarios.delete(scenario.id);
    _compareIds.remove(scenario.id);
    _refresh();
  }

  /// Resets [controller] to an unsaved fresh demo draft. Used after the
  /// active project or scenario gets deleted out from under it.
  void _resetActiveDraft(ProjectController controller, AppLocalizations l) {
    controller.newProject(
      name: _uniqueName(
        l.projectListNewDefaultName,
        _projectList.map((p) => p.name).toSet(),
      ),
      defaultArrayLabel: l.demoArrayLabel,
      defaultInverterLabel: l.demoInverterLabel,
      defaultBatteryLabel: l.demoBatteryLabel,
    );
  }

  Future<void> _exportScenario(ScenarioRow scenario) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final filename = '${_safeFilename(scenario.name)}.json';
      final ok = await _fileIo.exportConfig(filename, scenario.config);
      if (!mounted) return;
      final String msg;
      if (!ok) {
        msg = l.projectListExportCancelled;
      } else if (kIsWeb) {
        msg = l.projectListDownloaded(filename);
      } else {
        msg = l.projectListExported(filename);
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.projectListExportFailed(e.toString()))));
    }
  }

  void _toggleCompare(ScenarioRow scenario, bool? value) {
    setState(() {
      if (value == true) {
        _compareIds.add(scenario.id);
      } else {
        _compareIds.remove(scenario.id);
      }
    });
  }

  void _openCompare() {
    final compare = context.read<ScenarioComparisonController>();
    compare.replaceSelection(_compareIds);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ScenarioComparePage(),
    ));
  }

  Future<String?> _promptText({
    required String title,
    required String initial,
    required String ok,
    required String cancel,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ok),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String ok,
    required String cancel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
        ],
      ),
    );
    return result ?? false;
  }

  String _uniqueName(String base, Set<String> existing) {
    if (!existing.contains(base)) return base;
    for (var i = 2; i < 1000; i++) {
      final candidate = '$base $i';
      if (!existing.contains(candidate)) return candidate;
    }
    return '$base ${DateTime.now().millisecondsSinceEpoch}';
  }

  String _safeFilename(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9_\-\.]+'), '_');
    return cleaned.isEmpty ? 'projekt' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _newProject,
                icon: const Icon(Icons.add),
                label: Text(l.projectListCreateButton),
              ),
              OutlinedButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.file_upload),
                label: Text(l.projectListImportTooltip),
              ),
              OutlinedButton.icon(
                onPressed: _saveCurrent,
                icon: const Icon(Icons.save),
                label: Text(l.projectListExportTooltip),
              ),
              FilledButton.tonalIcon(
                onPressed: _compareIds.length >= 2 ? _openCompare : null,
                icon: const Icon(Icons.compare_arrows),
                label: Text(l.projectsTabCompareButton(_compareIds.length)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildProjectList(context)),
        ],
      ),
    );
  }

  Widget _buildProjectList(BuildContext context) {
    if (_projectList.isEmpty) {
      final l = AppLocalizations.of(context);
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.solar_power, size: 72, color: scheme.outline),
            const SizedBox(height: 12),
            Text(l.projectListEmpty, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l.projectListEmptyHint,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return Card(
      child: ListView.builder(
        itemCount: _projectList.length,
        itemBuilder: (context, i) => _ProjectExpansionTile(
          key: ValueKey(_projectList[i].id),
          project: _projectList[i],
          scenarios: _scenarios.listForProject(_projectList[i].id),
          compareIds: _compareIds,
          onOpenScenario: _openScenario,
          onDuplicateScenario: _duplicateScenario,
          onRenameScenario: _renameScenario,
          onDeleteScenario: _deleteScenario,
          onExportScenario: _exportScenario,
          onToggleCompare: _toggleCompare,
          onRenameProject: _renameProject,
          onDeleteProject: _deleteProject,
          onNewScenario: _newScenario,
        ),
      ),
    );
  }
}

class _ProjectExpansionTile extends StatelessWidget {
  const _ProjectExpansionTile({
    super.key,
    required this.project,
    required this.scenarios,
    required this.compareIds,
    required this.onOpenScenario,
    required this.onDuplicateScenario,
    required this.onRenameScenario,
    required this.onDeleteScenario,
    required this.onExportScenario,
    required this.onToggleCompare,
    required this.onRenameProject,
    required this.onDeleteProject,
    required this.onNewScenario,
  });

  final ProjectRow project;
  final List<ScenarioRow> scenarios;
  final Set<String> compareIds;
  final void Function(ProjectRow, ScenarioRow) onOpenScenario;
  final void Function(ScenarioRow) onDuplicateScenario;
  final void Function(ScenarioRow) onRenameScenario;
  final void Function(ScenarioRow) onDeleteScenario;
  final void Function(ScenarioRow) onExportScenario;
  final void Function(ScenarioRow, bool?) onToggleCompare;
  final void Function(ProjectRow) onRenameProject;
  final void Function(ProjectRow) onDeleteProject;
  final void Function(ProjectRow) onNewScenario;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(project.name),
      subtitle: Text(l.projectsTabScenarioCount(scenarios.length)),
      trailing: PopupMenuButton<String>(
        onSelected: (key) {
          switch (key) {
            case 'new-scenario':
              onNewScenario(project);
              break;
            case 'rename':
              onRenameProject(project);
              break;
            case 'delete':
              onDeleteProject(project);
              break;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'new-scenario', child: Text(l.projectsTabPopupNewScenario)),
          PopupMenuItem(value: 'rename', child: Text(l.projectsTabPopupRename)),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text(l.projectsTabPopupDeleteProject)),
        ],
      ),
      children: [
        if (scenarios.isEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.info_outline),
            title: Text(l.projectsTabEmptyScenarios),
          )
        else
          for (final s in scenarios)
            ListTile(
              key: ValueKey('scenario-${s.id}'),
              leading: Checkbox(
                value: compareIds.contains(s.id),
                onChanged: (v) => onToggleCompare(s, v),
              ),
              title: Text(s.name),
              subtitle: Text('Engine ${s.engineVersion} · ${s.inputHash.substring(0, 8)}'),
              onTap: () => onOpenScenario(project, s),
              trailing: Wrap(spacing: 0, children: [
                IconButton(
                  tooltip: l.projectsTabDuplicateTooltip,
                  icon: const Icon(Icons.content_copy),
                  onPressed: () => onDuplicateScenario(s),
                ),
                IconButton(
                  tooltip: l.projectsTabRenameTooltip,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onRenameScenario(s),
                ),
                IconButton(
                  tooltip: l.projectsTabExportTooltip,
                  icon: const Icon(Icons.file_download),
                  onPressed: () => onExportScenario(s),
                ),
                IconButton(
                  tooltip: l.projectsTabDeleteTooltip,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDeleteScenario(s),
                ),
              ]),
            ),
      ],
    );
  }
}

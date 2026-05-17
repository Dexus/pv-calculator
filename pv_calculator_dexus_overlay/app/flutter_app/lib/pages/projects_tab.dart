import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../persistence/file_io.dart';
import '../persistence/project_store.dart';
import '../state/config_draft.dart';
import '../state/project_controller.dart';

/// Projects tab: list / create / import / export / delete. Replaces the
/// stack-based `ProjectListPage` from the previous flow; selecting a
/// project mutates the [ProjectController] in place and the user
/// switches to another tab (Einstrahlung / PV-Arrays / Auswertung) to
/// keep working on it.
class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key, this.store, this.fileIo});

  /// Injection points for tests; production uses defaults.
  final ProjectStore? store;
  final FileIo? fileIo;

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  late final ProjectStore _store = widget.store ?? ProjectStore();
  late final FileIo _fileIo = widget.fileIo ?? const FileIo();
  Future<List<String>>? _names;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _names = _store.listProjects();
    });
  }

  Future<void> _openProject(String name) async {
    final controller = context.read<ProjectController>();
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final config = await _store.loadConfig(name);
    if (!mounted) return;
    if (config == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.projectListLoadFailed(name))));
      return;
    }
    controller.loadDraft(name, ConfigDraft.fromConfig(config));
    // Hop to the Einstrahlung tab so the user immediately sees the
    // location + Lade Daten controls for the freshly-opened project.
    DefaultTabController.of(context).animateTo(1);
  }

  Future<void> _newProject() async {
    final l = AppLocalizations.of(context);
    final names = (await _store.listProjects()).toSet();
    if (!mounted) return;
    context.read<ProjectController>().newProject(
          name: _uniqueName(l.projectListNewDefaultName, names),
          defaultArrayLabel: l.demoArrayLabel,
          defaultInverterLabel: l.demoInverterLabel,
          defaultBatteryLabel: l.demoBatteryLabel,
        );
    DefaultTabController.of(context).animateTo(1);
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final imported = await _fileIo.importConfig();
      if (imported == null || !mounted) return;
      final existing = (await _store.listProjects()).toSet();
      if (!mounted) return;
      var targetName = imported.suggestedName;
      if (existing.contains(targetName)) {
        final action = await _askImportConflict(targetName);
        if (!mounted || action == _ImportConflictAction.cancel) return;
        if (action == _ImportConflictAction.rename) {
          targetName = _uniqueName(targetName, existing);
        }
      }
      await _store.saveConfig(targetName, imported.config);
      if (!mounted) return;
      _refresh();
      messenger.showSnackBar(SnackBar(content: Text(l.projectListImported(targetName))));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.projectListImportFailed(e.toString()))));
    }
  }

  Future<_ImportConflictAction> _askImportConflict(String name) async {
    final action = await showDialog<_ImportConflictAction>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l.projectListConflictTitle),
          content: Text(l.projectListConflictBody(name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, _ImportConflictAction.cancel),
              child: Text(l.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _ImportConflictAction.rename),
              child: Text(l.projectListConflictRename),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _ImportConflictAction.overwrite),
              child: Text(l.projectListConflictOverwrite),
            ),
          ],
        );
      },
    );
    return action ?? _ImportConflictAction.cancel;
  }

  Future<void> _export(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final config = await _store.loadConfig(name);
      if (!mounted) return;
      if (config == null) {
        messenger.showSnackBar(SnackBar(content: Text(l.projectListLoadFailed(name))));
        return;
      }
      final filename = '${_safeFilename(name)}.json';
      final ok = await _fileIo.exportConfig(filename, config);
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

  Future<void> _delete(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l.projectListDeleteTitle),
          content: Text(l.projectListDeleteBody(name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.commonDelete)),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _store.deleteProject(name);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _saveCurrent() async {
    final controller = context.read<ProjectController>();
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      await _store.saveConfig(
        controller.projectName.trim(),
        controller.draft.build(),
      );
      if (!mounted) return;
      _refresh();
      messenger.showSnackBar(SnackBar(content: Text(l.projectListExported(controller.projectName))));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.projectListSaveFailed(e.toString()))));
    }
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
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _names,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final names = snapshot.data ?? const [];
                if (names.isEmpty) {
                  final scheme = Theme.of(context).colorScheme;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.solar_power, size: 72, color: scheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          l.projectListEmpty,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.projectListEmptyHint,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    ),
                  );
                }
                return Card(
                  child: ListView.separated(
                    itemCount: names.length,
                    separatorBuilder: (_, _) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      final name = names[i];
                      return ListTile(
                        title: Text(name),
                        onTap: () => _openProject(name),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.file_download),
                            tooltip: l.projectListExportTooltip,
                            onPressed: () => _export(name),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l.projectListDeleteTooltip,
                            onPressed: () => _delete(name),
                          ),
                        ]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _ImportConflictAction { overwrite, rename, cancel }

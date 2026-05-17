import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../persistence/file_io.dart';
import '../persistence/project_store.dart';
import '../state/config_draft.dart';
import '../state/project_controller.dart';
import 'app_drawer.dart';
import 'forms/editor_page.dart';
import 'results/results_page.dart';

class ProjectListPage extends StatefulWidget {
  const ProjectListPage({super.key, this.store, this.fileIo});

  /// Injection points for tests; production uses defaults.
  final ProjectStore? store;
  final FileIo? fileIo;

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage> {
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
    final config = await _store.loadConfig(name);
    if (!mounted) return;
    if (config == null) {
      messenger.showSnackBar(SnackBar(content: Text('Projekt "$name" konnte nicht geladen werden.')));
      return;
    }
    controller.loadDraft(name, ConfigDraft.fromConfig(config));
    _pushEditor();
  }

  Future<void> _newProject() async {
    final names = (await _store.listProjects()).toSet();
    if (!mounted) return;
    context.read<ProjectController>().newProject(name: _uniqueName('Neues Projekt', names));
    _pushEditor();
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(SnackBar(content: Text('Importiert: $targetName')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Import fehlgeschlagen: $e')));
    }
  }

  Future<_ImportConflictAction> _askImportConflict(String name) async {
    final action = await showDialog<_ImportConflictAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Projekt existiert bereits'),
        content: Text(
          '"$name" ist bereits gespeichert. Soll der Import diese Version überschreiben '
          'oder unter einem neuen Namen abgelegt werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ImportConflictAction.cancel),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ImportConflictAction.rename),
            child: const Text('Umbenennen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _ImportConflictAction.overwrite),
            child: const Text('Überschreiben'),
          ),
        ],
      ),
    );
    return action ?? _ImportConflictAction.cancel;
  }

  Future<void> _export(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final config = await _store.loadConfig(name);
      if (!mounted) return;
      if (config == null) {
        messenger.showSnackBar(SnackBar(content: Text('Projekt "$name" konnte nicht geladen werden.')));
        return;
      }
      final filename = '${_safeFilename(name)}.json';
      final ok = await _fileIo.exportConfig(filename, config);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(ok ? (kIsWeb ? 'Heruntergeladen: $filename' : 'Exportiert: $filename') : 'Export abgebrochen'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $e')));
    }
  }

  Future<void> _delete(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Projekt löschen?'),
        content: Text('"$name" wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.deleteProject(name);
    if (!mounted) return;
    _refresh();
  }

  void _pushEditor() {
    final controller = context.read<ProjectController>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (innerContext) => ChangeNotifierProvider<ProjectController>.value(
          value: controller,
          child: Builder(
            builder: (editorContext) => EditorPage(
              onRunRequested: () async {
                final editorMessenger = ScaffoldMessenger.of(editorContext);
                try {
                  await _store.saveConfig(
                    controller.projectName.trim(),
                    controller.draft.build(),
                  );
                } catch (e) {
                  if (!editorContext.mounted) return;
                  editorMessenger.showSnackBar(SnackBar(
                    content: Text('Speichern fehlgeschlagen: $e'),
                  ));
                  // Block navigation so the user can fix the project name /
                  // storage condition before losing their results.
                  return;
                }
                if (!editorContext.mounted) return;
                Navigator.of(editorContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangeNotifierProvider<ProjectController>.value(
                      value: controller,
                      child: ResultsPage(
                        onExportCsv: ({required String filename, required String content}) async {
                          await _fileIo.exportCsv(filename: _safeFilename(filename), content: content);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ).then((_) {
      if (mounted) _refresh();
    });
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
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('PV Calculator — Projekte'),
        actions: [
          IconButton(onPressed: _import, icon: const Icon(Icons.file_upload), tooltip: 'Importieren'),
          IconButton(onPressed: _newProject, icon: const Icon(Icons.add), tooltip: 'Neues Projekt'),
        ],
      ),
      body: FutureBuilder<List<String>>(
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
                    'Noch keine Projekte gespeichert.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lege ein neues Projekt an oder importiere ein gespeichertes JSON.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _newProject,
                    icon: const Icon(Icons.add),
                    label: const Text('Neues Projekt erstellen'),
                  ),
                ]),
              ),
            );
          }
          return ListView.separated(
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
                    tooltip: 'Exportieren',
                    onPressed: () => _export(name),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Löschen',
                    onPressed: () => _delete(name),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

enum _ImportConflictAction { overwrite, rename, cancel }

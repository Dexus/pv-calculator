import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../persistence/file_io.dart';
import '../persistence/project_store.dart';
import '../state/config_draft.dart';
import '../state/project_controller.dart';
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
    final config = await _store.loadConfig(name);
    if (config == null || !mounted) return;
    controller.loadDraft(name, ConfigDraft.fromConfig(config));
    _pushEditor();
  }

  void _newProject() {
    context.read<ProjectController>().newProject();
    _pushEditor();
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final imported = await _fileIo.importConfig();
      if (imported == null || !mounted) return;
      await _store.saveConfig(imported.suggestedName, imported.config);
      if (!mounted) return;
      _refresh();
      messenger.showSnackBar(SnackBar(content: Text('Importiert: ${imported.suggestedName}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import fehlgeschlagen: $e')));
    }
  }

  Future<void> _export(String name) async {
    try {
      final config = await _store.loadConfig(name);
      if (config == null) return;
      final ok = await _fileIo.exportConfig('$name.json', config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? (kIsWeb ? 'Heruntergeladen: $name.json' : 'Exportiert: $name.json') : 'Export abgebrochen'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $e')));
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
                // Auto-save before showing results.
                try {
                  await _store.saveConfig(controller.projectName, controller.draft.build());
                } catch (_) {}
                if (!editorContext.mounted) return;
                Navigator.of(editorContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangeNotifierProvider<ProjectController>.value(
                      value: controller,
                      child: ResultsPage(
                        onExportCsv: ({required String filename, required String content}) async {
                          await _fileIo.exportCsv(filename: filename, content: content);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Noch keine Projekte gespeichert.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _newProject,
                  icon: const Icon(Icons.add),
                  label: const Text('Neues Projekt erstellen'),
                ),
              ]),
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

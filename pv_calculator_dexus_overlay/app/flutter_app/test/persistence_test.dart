import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/project_store.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_engine/pv_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saveConfig + listProjects + loadConfig round-trips', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProjectStore(prefs: prefs);
    final config = ConfigDraft.demo().build();

    await store.saveConfig('Demo', config);

    final names = await store.listProjects();
    expect(names, ['Demo']);

    final loaded = await store.loadConfig('Demo');
    expect(loaded, isNotNull);
    expect(
      jsonEncode(loaded!.toJson()),
      jsonEncode(config.toJson()),
      reason: 'round-trip should be byte-identical',
    );
  });

  test('saving the same name twice keeps a single index entry', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProjectStore(prefs: prefs);
    final config = ConfigDraft.demo().build();

    await store.saveConfig('Demo', config);
    await store.saveConfig('Demo', config);

    expect(await store.listProjects(), ['Demo']);
  });

  test('deleteProject removes the entry and updates the index', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProjectStore(prefs: prefs);
    final config = ConfigDraft.demo().build();

    await store.saveConfig('A', config);
    await store.saveConfig('B', config);
    expect(await store.listProjects(), ['A', 'B']);

    await store.deleteProject('A');
    expect(await store.listProjects(), ['B']);
    expect(await store.loadConfig('A'), isNull);
  });

  test('saveConfig rejects empty project names', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProjectStore(prefs: prefs);
    expect(() => store.saveConfig('  ', _minimalConfig()), throwsArgumentError);
  });

  test('listProjects returns empty when the store has no entries', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProjectStore(prefs: prefs);
    expect(await store.listProjects(), isEmpty);
  });

  test('loadConfig returns null for a corrupt entry instead of throwing', () async {
    SharedPreferences.setMockInitialValues({
      '${ProjectStore.entryPrefix}Broken': 'not json',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = ProjectStore(prefs: prefs);
    expect(await store.loadConfig('Broken'), isNull);
  });
}

SimulationConfig _minimalConfig() => const SimulationConfig(
      arrays: [PvArray(id: 'a', label: 'A', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i')],
      inverters: [Inverter(id: 'i', label: 'I', maxAcKw: 1.0)],
      loadProfile: LoadProfile(dailyKwh: 1),
    );

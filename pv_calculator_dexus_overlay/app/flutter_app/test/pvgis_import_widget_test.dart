import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/persistence/file_io.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/arrays_section.dart';
import 'package:pv_engine/pv_engine.dart';

/// FileIo stub that returns a deterministic PVGIS dataset without
/// touching the filesystem or the platform file picker.
class _FakeFileIo implements FileIo {
  _FakeFileIo({this.result});

  ImportedPvgis? result;
  int callCount = 0;

  @override
  Future<ImportedPvgis?> importPvgisJson() async {
    callCount += 1;
    return result;
  }

  // Unused in this widget test.
  @override
  Future<bool> exportConfig(String suggestedName, SimulationConfig config) async => true;
  @override
  Future<bool> exportCsv({required String filename, required String content}) async => true;
  @override
  Future<ImportedProject?> importConfig() async => null;
}

ImportedPvgis _buildFakeImport() {
  final entries = <PvgisHourlyEntry>[
    PvgisHourlyEntry(
      timestampUtc: DateTime.utc(2020, 6, 21, 12),
      poaIrradianceWPerM2: 950.0, ambientTempC: 21.0, windMS: 2.5,
    ),
  ];
  return ImportedPvgis(
    sourceLabel: 'mock-pvgis',
    data: PvgisHourlyData(entries: entries, latitudeDeg: 50.1, longitudeDeg: 8.6),
  );
}

void main() {
  testWidgets('PVGIS import button attaches data to the array and reflects status', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final controller = ProjectController();
    final fileIo = _FakeFileIo(result: _buildFakeImport());

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: Scaffold(body: SingleChildScrollView(child: ArraysSection(fileIo: fileIo))),
      ),
    ));
    await tester.pumpAndSettle();

    // Initial state: no PVGIS data, demo array has id "south-roof".
    expect(find.text('Wetterquelle: synthetisches Demo-Modell'), findsOneWidget);
    expect(controller.draft.hasWeatherFor('south-roof'), isFalse);

    // Tap import.
    await tester.tap(find.byKey(const Key('pvgis-import-south-roof')));
    await tester.pumpAndSettle();

    expect(fileIo.callCount, 1);
    expect(controller.draft.hasWeatherFor('south-roof'), isTrue);
    expect(find.text('PVGIS-Daten geladen'), findsOneWidget);
    // Remove button is rendered once data is attached.
    expect(find.byKey(const Key('pvgis-remove-south-roof')), findsOneWidget);

    // Build a real engine source through the draft.
    expect(controller.draft.buildWeatherSource(), isA<HourlyWeatherSeries>());

    // Tap remove.
    await tester.tap(find.byKey(const Key('pvgis-remove-south-roof')));
    await tester.pumpAndSettle();
    expect(controller.draft.hasWeatherFor('south-roof'), isFalse);
    expect(find.text('Wetterquelle: synthetisches Demo-Modell'), findsOneWidget);
  });

  testWidgets('stores weather under the exact array id (no implicit trim)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    // The simulator queries WeatherQuery by the exact PvArray.id string.
    // If the import handler trimmed the key, an id like ' foo ' would
    // silently fall back to synthetic. Build an array with a
    // surrounding-space id and verify the import key matches.
    final draft = ConfigDraft(
      arrays: [PvArrayDraft(id: ' spaced ', label: 'Test', inverterId: 'inv')],
      inverters: [InverterDraft(id: 'inv', label: 'Inv', maxAcKw: 5)],
      batteries: [],
      loadProfile: LoadProfileDraft(dailyKwh: 1),
    );
    final controller = ProjectController(draft: draft);
    final fileIo = _FakeFileIo(result: _buildFakeImport());

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: Scaffold(body: SingleChildScrollView(child: ArraysSection(fileIo: fileIo))),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pvgis-import- spaced ')));
    await tester.pumpAndSettle();

    expect(controller.draft.hasWeatherFor(' spaced '), isTrue,
        reason: 'Weather must be keyed under the exact PvArray.id used by the simulator.');
    expect(controller.draft.hasWeatherFor('spaced'), isFalse,
        reason: 'Import handler must not implicitly trim the key.');
  });

  testWidgets('cancelled import (user closes file picker) leaves state untouched', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final controller = ProjectController();
    final fileIo = _FakeFileIo(); // returns null

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: Scaffold(body: SingleChildScrollView(child: ArraysSection(fileIo: fileIo))),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pvgis-import-south-roof')));
    await tester.pumpAndSettle();

    expect(fileIo.callCount, 1);
    expect(controller.draft.hasWeatherFor('south-roof'), isFalse);
    expect(find.text('Wetterquelle: synthetisches Demo-Modell'), findsOneWidget);
  });
}

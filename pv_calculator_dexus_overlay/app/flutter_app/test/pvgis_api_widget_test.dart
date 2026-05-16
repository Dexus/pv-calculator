import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/services/pvgis_api.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/arrays_section.dart';

String _samplePvgisBody({int hours = 24}) {
  final entries = <Map<String, Object?>>[
    for (var h = 0; h < hours; h++)
      {
        'time': '20200101:${h.toString().padLeft(2, '0')}10',
        'G(i)': h >= 8 && h < 18 ? 600.0 : 0.0,
        'T2m': 18.0,
        'WS10m': 2.0,
        'P': h >= 8 && h < 18 ? 2400.0 : 0.0,
      }
  ];
  return jsonEncode({
    'inputs': {
      'location': {'latitude': 50.1, 'longitude': 8.6},
      'mounting_system': {
        'fixed': {
          'slope': {'value': 35.0, 'optimal': false},
          'azimuth': {'value': 0.0, 'optimal': false},
        }
      }
    },
    'outputs': {'hourly': entries},
  });
}

void main() {
  testWidgets('PVGIS-API button fetches and attaches data to the array', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    Uri? captured;
    final mockHttp = MockClient((request) async {
      captured = request.url;
      return http.Response(_samplePvgisBody(), 200,
          headers: {'content-type': 'application/json'});
    });
    final controller = ProjectController(); // demo array id: south-roof
    final api = PvgisApiService(client: mockHttp, minimumInterval: Duration.zero);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: Scaffold(
          body: SingleChildScrollView(
            child: ArraysSection(pvgisApi: api),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Sanity: no PVGIS data yet, synthetic message visible.
    expect(controller.draft.hasWeatherFor('south-roof'), isFalse);
    expect(find.text('Wetterquelle: synthetisches Demo-Modell'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pvgis-fetch-api-south-roof')));
    await tester.pumpAndSettle();

    // Request was issued against the public PVGIS host with the
    // array's orientation translated to PVGIS conventions.
    expect(captured, isNotNull);
    expect(captured!.host, 're.jrc.ec.europa.eu');
    expect(captured!.queryParameters['aspect'], '0'); // south → PVGIS 0
    expect(captured!.queryParameters['angle'], '35');
    expect(captured!.queryParameters['lat'], '50.100000');

    // Series is now attached to the demo array.
    expect(controller.draft.hasWeatherFor('south-roof'), isTrue);
    expect(find.text('PVGIS-Daten geladen'), findsOneWidget);
    final info = controller.draft.weatherInfoFor('south-roof')!;
    expect(info.sourceLabel, startsWith('PVGIS-API'));
    expect(info.entryCount, 24);
  });

  testWidgets('API failure surfaces an error SnackBar and leaves draft untouched',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final mockHttp = MockClient((_) async => http.Response('upstream error', 500));
    final controller = ProjectController();
    final api = PvgisApiService(client: mockHttp, minimumInterval: Duration.zero);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: Scaffold(
          body: SingleChildScrollView(
            child: ArraysSection(pvgisApi: api),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pvgis-fetch-api-south-roof')));
    await tester.pumpAndSettle();

    expect(controller.draft.hasWeatherFor('south-roof'), isFalse);
    // SnackBar with a "500" mention should be visible.
    expect(find.textContaining('500'), findsOneWidget);
  });

  testWidgets('refuses to fetch when the array id is empty', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    var called = false;
    final mockHttp = MockClient((_) async {
      called = true;
      return http.Response(_samplePvgisBody(), 200);
    });
    final controller = ProjectController();
    // Blank out the demo array's id.
    controller.draft.arrays[0].id = '';
    final api = PvgisApiService(client: mockHttp, minimumInterval: Duration.zero);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: Scaffold(
          body: SingleChildScrollView(
            child: ArraysSection(pvgisApi: api),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pvgis-fetch-api-')));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.textContaining('Modulfeld-ID'), findsOneWidget);
  });
}

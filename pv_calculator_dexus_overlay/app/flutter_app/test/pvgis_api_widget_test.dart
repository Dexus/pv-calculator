import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/services/pvgis_api.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/arrays_section.dart';

import '_test_localization.dart';

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

    await tester.pumpWidget(germanMaterialApp(
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
    // Year window comes from the draft defaults (2020–2023).
    expect(captured!.queryParameters['startyear'], '2020');
    expect(captured!.queryParameters['endyear'], '2023');
    // Radiation database is "PVGIS Auto" by default, so the param is
    // omitted from the URL.
    expect(captured!.queryParameters.containsKey('raddatabase'), isFalse);

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

    await tester.pumpWidget(germanMaterialApp(
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

    await tester.pumpWidget(germanMaterialApp(
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

  testWidgets('honours custom startYear/endYear/radDatabase from the draft',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    Uri? captured;
    final mockHttp = MockClient((request) async {
      captured = request.url;
      return http.Response(_samplePvgisBody(), 200);
    });
    final controller = ProjectController()
      ..draft.pvgisStartYear = 2015
      ..draft.pvgisEndYear = 2019
      ..draft.pvgisRadDatabase = 'PVGIS-ERA5';
    final api = PvgisApiService(client: mockHttp, minimumInterval: Duration.zero);

    await tester.pumpWidget(germanMaterialApp(
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

    expect(captured, isNotNull);
    expect(captured!.queryParameters['startyear'], '2015');
    expect(captured!.queryParameters['endyear'], '2019');
    expect(captured!.queryParameters['raddatabase'], 'PVGIS-ERA5');
  });

  testWidgets('shared section service serializes requests across array rows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2500));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    // Build a draft with two arrays so two rows render side by side.
    final controller = ProjectController()
      ..draft.arrays.add(PvArrayDraft(
        id: 'east-roof',
        label: 'Ost',
        peakKw: 2.0, tiltDeg: 30, azimuthDeg: 90,
        inverterId: 'main',
      ));

    // Capture the absolute order of requests received by the mocked
    // PVGIS endpoint. Each handler waits 50 ms so a concurrent run
    // would interleave; the rate limiter must serialize them instead.
    final calls = <String>[];
    final mockHttp = MockClient((request) async {
      calls.add('start:${request.url.queryParameters["aspect"]}');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      calls.add('end:${request.url.queryParameters["aspect"]}');
      return http.Response(_samplePvgisBody(), 200);
    });
    final api = PvgisApiService(
      client: mockHttp,
      minimumInterval: const Duration(milliseconds: 200),
    );

    await tester.pumpWidget(germanMaterialApp(
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

    // Tap both API buttons back-to-back without awaiting in between.
    final southBtn = find.byKey(const Key('pvgis-fetch-api-south-roof'));
    final eastBtn = find.byKey(const Key('pvgis-fetch-api-east-roof'));
    await tester.tap(southBtn);
    await tester.pump();
    await tester.tap(eastBtn);
    await tester.pumpAndSettle();

    // Each request issues "start" before "end" — if the lazy
    // per-row default was still in place, the second start could land
    // before the first end. With one shared rate-limited service the
    // sequence has to be start/end pairs in order.
    expect(calls.length, 4);
    expect(calls[0], startsWith('start:'));
    expect(calls[1], 'end:${calls[0].substring(6)}');
    expect(calls[2], startsWith('start:'));
    expect(calls[3], 'end:${calls[2].substring(6)}');
    expect(controller.draft.hasWeatherFor('south-roof'), isTrue);
    expect(controller.draft.hasWeatherFor('east-roof'), isTrue);
  });
}

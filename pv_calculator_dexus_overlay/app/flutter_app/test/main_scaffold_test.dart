import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pv_calculator_app/l10n/generated/app_localizations.dart';
import 'package:pv_calculator_app/pages/main_scaffold.dart';
import 'package:pv_calculator_app/services/pvgis_api.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/state/settings_controller.dart';

Widget _scaffold({required ProjectController controller, required SettingsController settings}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: controller),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MainScaffold(),
      ),
    );

void main() {
  testWidgets('MainScaffold renders four tab labels and project name', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final api = PvgisApiService(
      client: MockClient((_) async => http.Response('{}', 500)),
      minimumInterval: Duration.zero,
    );
    addTearDown(api.dispose);
    final settings = SettingsController();
    await settings.load();
    addTearDown(settings.dispose);
    final controller = ProjectController(pvgisApi: api);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_scaffold(controller: controller, settings: settings));
    await tester.pumpAndSettle();

    // All four tab labels must be rendered in the tab bar (English locale).
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Irradiance'), findsOneWidget);
    expect(find.text('PV arrays'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    // AppBar should show the project name.
    expect(find.text(controller.projectName), findsOneWidget);
  });

  testWidgets('Switching to Results tab shows the run button', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final api = PvgisApiService(
      client: MockClient((_) async => http.Response('{}', 500)),
      minimumInterval: Duration.zero,
    );
    addTearDown(api.dispose);
    final settings = SettingsController();
    await settings.load();
    addTearDown(settings.dispose);
    final controller = ProjectController(pvgisApi: api);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_scaffold(controller: controller, settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('results-run-button')), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/services/geocoding.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/project_section.dart';

class _FakeGeocoder implements GeocodingService {
  _FakeGeocoder(this.results);
  final List<GeocodeResult> results;
  List<String> lastQueries = [];
  @override
  Future<List<GeocodeResult>> search(String query, {int limit = 5}) async {
    lastQueries.add(query);
    return results;
  }
}

class _ThrowingGeocoder implements GeocodingService {
  _ThrowingGeocoder(this.exception);
  final GeocodingException exception;
  @override
  Future<List<GeocodeResult>> search(String query, {int limit = 5}) async {
    throw exception;
  }
}

Widget _harness(GeocodingService geocoder, ProjectController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: SingleChildScrollView(child: ProjectSection(geocoder: geocoder)),
      ),
    ),
  );
}

void main() {
  testWidgets('search button populates lat/lon when a result is selected', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final controller = ProjectController();
    final geocoder = _FakeGeocoder([
      const GeocodeResult(
        displayName: 'Marktplatz, Frankfurt am Main',
        latitudeDeg: 50.11055,
        longitudeDeg: 8.68215,
      ),
    ]);

    await tester.pumpWidget(_harness(geocoder, controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('address-search-field')), 'Marktplatz Frankfurt');
    await tester.tap(find.byKey(const Key('address-search-button')));
    await tester.pumpAndSettle();

    expect(geocoder.lastQueries, contains('Marktplatz Frankfurt'));
    // Result appears in the list.
    expect(find.text('Marktplatz, Frankfurt am Main'), findsOneWidget);

    await tester.tap(find.text('Marktplatz, Frankfurt am Main'));
    await tester.pumpAndSettle();

    // Coordinates rounded to 5 decimals and pushed into the draft.
    expect(controller.draft.latitudeDeg, closeTo(50.11055, 1e-6));
    expect(controller.draft.longitudeDeg, closeTo(8.68215, 1e-6));
    // Result list collapses once a pick is applied.
    expect(find.text('Marktplatz, Frankfurt am Main'), findsNothing);
  });

  testWidgets('shows "Keine Treffer gefunden." when the geocoder returns empty', (tester) async {
    final controller = ProjectController();
    final geocoder = _FakeGeocoder(const []);

    await tester.pumpWidget(_harness(geocoder, controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('address-search-field')), 'Nirgendwo');
    await tester.tap(find.byKey(const Key('address-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('Keine Treffer gefunden.'), findsOneWidget);
  });

  testWidgets('surfaces GeocodingException messages in the UI', (tester) async {
    final controller = ProjectController();
    final geocoder = _ThrowingGeocoder(GeocodingException('boom'));

    await tester.pumpWidget(_harness(geocoder, controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('address-search-field')), 'x');
    await tester.tap(find.byKey(const Key('address-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('empty query does not invoke the geocoder', (tester) async {
    final controller = ProjectController();
    final geocoder = _FakeGeocoder(const []);

    await tester.pumpWidget(_harness(geocoder, controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('address-search-button')));
    await tester.pumpAndSettle();

    expect(geocoder.lastQueries, isEmpty);
  });
}

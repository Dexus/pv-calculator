import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/editor_page.dart';

void main() {
  testWidgets('disables Run when the draft is invalid', (tester) async {
    final controller = ProjectController(
      draft: ConfigDraft(
        // No arrays / no inverters → invalid by construction.
        loadProfile: LoadProfileDraft(dailyKwh: 5),
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: const EditorPage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Konfiguration unvollständig'), findsOneWidget);

    final runButton = tester.widget<FilledButton>(find.byKey(const Key('run-button')));
    expect(runButton.onPressed, isNull);
  });

  testWidgets('enables Run for the demo project and runs successfully', (tester) async {
    final controller = ProjectController();

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: const EditorPage(),
      ),
    ));
    await tester.pumpAndSettle();

    final runButton = tester.widget<FilledButton>(find.byKey(const Key('run-button')));
    expect(runButton.onPressed, isNotNull);

    final ok = controller.run();
    expect(ok, isTrue);
    expect(controller.result, isNotNull);
    expect(controller.result!.summary.pvAcKwh, greaterThan(0));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/widgets/forms/_field.dart';

import '../../_test_localization.dart';

void main() {
  group('shared form-field Semantics', () {
    testWidgets('NumberField announces label, hint, and isTextField',
        (tester) async {
      const fieldKey = Key('test-number-field');
      await tester.pumpWidget(
        germanMaterialApp(
          home: Scaffold(
            body: NumberField(
              key: fieldKey,
              label: 'Daily kWh',
              initialValue: 10.0,
              helpText: 'Average household demand',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byKey(fieldKey));
      expect(node.label, 'Daily kWh');
      expect(node.hint, 'Average household demand');
      expect(node.flagsCollection.isTextField, isTrue);
    });

    testWidgets('NumberField uses semanticsLabel override when provided',
        (tester) async {
      const fieldKey = Key('semantics-override');
      await tester.pumpWidget(
        germanMaterialApp(
          home: Scaffold(
            body: NumberField(
              key: fieldKey,
              label: 'NOCT',
              semanticsLabel: 'Nominal operating cell temperature',
              initialValue: 45.0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byKey(fieldKey));
      expect(node.label, 'Nominal operating cell temperature');
      expect(node.hint, isEmpty);
      expect(node.flagsCollection.isTextField, isTrue);
    });

    testWidgets('IntField forwards label and hint through to Semantics',
        (tester) async {
      const fieldKey = Key('int-field');
      await tester.pumpWidget(
        germanMaterialApp(
          home: Scaffold(
            body: IntField(
              key: fieldKey,
              label: 'Module count',
              initialValue: 12,
              helpText: 'Number of modules in this string',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byKey(fieldKey));
      expect(node.label, 'Module count');
      expect(node.hint, 'Number of modules in this string');
      expect(node.flagsCollection.isTextField, isTrue);
    });

    testWidgets('StringField marks the required suffix in the visible label '
        'but keeps the semantics label clean when override is set',
        (tester) async {
      const fieldKey = Key('string-field');
      await tester.pumpWidget(
        germanMaterialApp(
          home: Scaffold(
            body: StringField(
              key: fieldKey,
              label: 'Label',
              initialValue: '',
              required: true,
              helpText: 'Visible on the project list',
              semanticsLabel: 'Project label',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byKey(fieldKey));
      expect(node.label, 'Project label');
      expect(node.hint, 'Visible on the project list');
      expect(node.flagsCollection.isTextField, isTrue);
    });

    testWidgets('StringField without semanticsLabel falls back to the visible '
        'label (including the required asterisk)', (tester) async {
      const fieldKey = Key('string-field-default');
      await tester.pumpWidget(
        germanMaterialApp(
          home: Scaffold(
            body: StringField(
              key: fieldKey,
              label: 'Name',
              initialValue: '',
              required: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byKey(fieldKey));
      expect(node.label, 'Name *');
      expect(node.hint, isEmpty);
      expect(node.flagsCollection.isTextField, isTrue);
    });
  });
}

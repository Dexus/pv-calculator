import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../state/project_controller.dart';
import '_field.dart';

class ProjectSection extends StatelessWidget {
  const ProjectSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Projekt', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          StringField(
            label: 'Projektname',
            initialValue: controller.projectName,
            required: true,
            onChanged: (v) => controller.projectName = v,
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 160, child: NumberField(
              label: 'Breitengrad',
              suffix: '°',
              initialValue: draft.latitudeDeg,
              min: -90, max: 90,
              onChanged: (v) {
                if (v != null) { draft.latitudeDeg = v; controller.touch(); }
              },
            )),
            SizedBox(width: 160, child: IntField(
              label: 'Start-Tag im Jahr',
              initialValue: draft.startDayOfYear,
              min: 1, max: 365,
              onChanged: (v) { draft.startDayOfYear = v; controller.touch(); },
            )),
            SizedBox(width: 160, child: IntField(
              label: 'Simulationstage',
              initialValue: draft.days,
              min: 1, max: 365,
              onChanged: (v) { draft.days = v; controller.touch(); },
            )),
            SizedBox(width: 160, child: IntField(
              label: 'Vorlauf-Tage',
              initialValue: draft.preRunDays,
              min: 0, max: 365,
              onChanged: (v) { draft.preRunDays = v; controller.touch(); },
            )),
            SizedBox(width: 200, child: NumberField(
              label: 'Einspeise-Limit',
              suffix: 'kW',
              initialValue: draft.gridExportLimitKw,
              allowNull: true,
              min: 0,
              onChanged: (v) { draft.gridExportLimitKw = v; controller.touch(); },
            )),
            SizedBox(width: 220, child: DropdownButtonFormField<TimeStep>(
              isExpanded: true,
              initialValue: draft.timeStep,
              decoration: const InputDecoration(labelText: 'Zeitschritt', isDense: true),
              items: const [
                DropdownMenuItem(value: TimeStep.hourly, child: Text('Stündlich', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: TimeStep.quarterHourly, child: Text('Viertelstündlich', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                if (v != null) { draft.timeStep = v; controller.touch(); }
              },
            )),
          ]),
        ]),
      ),
    );
  }
}

@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/database.dart';
import 'package:pv_calculator_app/persistence/project_repository.dart';

/// Browser-targeted smoke test for the IndexedDB-backed web persistence
/// path. Excluded from the default `flutter test` VM run by `@TestOn` so
/// CI stays green without a Chromium environment; invoke explicitly with
///
///     flutter test -p chrome test/persistence/web_persistence_test.dart
///
/// to exercise the round-trip the VM tests can't reach.
void main() {
  test('AppDatabase.open() round-trips a project through IndexedDB', () async {
    // Per-run filename so leftover data from a previous run can't satisfy
    // the assertion by accident — both opens land on the same IDB origin.
    final fileName = 'pv_test_${DateTime.now().microsecondsSinceEpoch}.sqlite';

    final first = await AppDatabase.open(fileName: fileName);
    expect(first.storageTier, DbStorageTier.indexedDb);
    ProjectRepository(first).createProject(name: 'Persist me');
    // Awaiting flush is what makes the assertion robust: without it the IDB
    // write can still be in flight when we close + reopen, and the second
    // open would race the commit.
    await first.flush();
    first.close();

    final second = await AppDatabase.open(fileName: fileName);
    expect(second.storageTier, DbStorageTier.indexedDb);
    final names = ProjectRepository(second).listProjects().map((p) => p.name);
    expect(names, contains('Persist me'));
    second.close();
  });
}

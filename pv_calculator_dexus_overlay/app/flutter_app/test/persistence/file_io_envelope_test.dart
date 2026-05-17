import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/file_io.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_engine/pv_engine.dart';

void main() {
  test('buildExportEnvelope wraps the config with engineVersion and inputHash', () {
    final config = ConfigDraft.demo().build();
    final envelope = buildExportEnvelope(config);
    expect(envelope['engineVersion'], equals(kEngineVersion));
    expect(envelope['inputHash'], equals(config.inputHash));
    expect(envelope['config'], isA<Map<String, dynamic>>());
    final inner = envelope['config'] as Map<String, dynamic>;
    expect(inner['arrays'], isNotEmpty);
  });

  test('parseImportedConfig accepts a Phase-7 envelope', () {
    final config = ConfigDraft.demo().build();
    final envelope = buildExportEnvelope(config);
    final round = jsonDecode(jsonEncode(envelope)) as Map<String, dynamic>;
    final parsed = parseImportedConfig(round);
    expect(parsed.inputHash, equals(config.inputHash));
  });

  test('parseImportedConfig accepts a pre-Phase-7 bare config', () {
    final config = ConfigDraft.demo().build();
    final bare = jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>;
    final parsed = parseImportedConfig(bare);
    expect(parsed.inputHash, equals(config.inputHash));
  });

  test('parseImportedConfig rejects neither-form documents', () {
    expect(
      () => parseImportedConfig(<String, dynamic>{'something': 'else'}),
      throwsArgumentError,
    );
  });
}

// Verifies the web stub surface of `share_helper.dart`. `flutter test`
// without a device runs in the VM (dart.library.io is true), so we
// import the stub directly here rather than via the conditional import
// in `file_io.dart` — that way the test asserts the file the web build
// actually picks up.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/share_helper.dart';

void main() {
  test('web stub reports kIsMobilePlatform == false', () {
    expect(kIsMobilePlatform, isFalse);
  });

  test('web stub throws UnsupportedError when invoked', () async {
    expect(
      () => shareBytesViaSheet(
        suggestedName: 'x.json',
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'application/json',
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('ShareOutcome exposes the three documented states', () {
    expect(ShareOutcome.values, hasLength(3));
    expect(ShareOutcome.values, containsAll([
      ShareOutcome.success,
      ShareOutcome.dismissed,
      ShareOutcome.unavailable,
    ]));
  });
}

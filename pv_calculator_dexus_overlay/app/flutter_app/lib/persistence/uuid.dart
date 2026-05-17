import 'dart:math';

const _hex = '0123456789abcdef';

/// Returns a randomly-generated RFC 4122 v4 UUID. Used as the primary key for
/// rows in [AppDatabase]. Pure Dart so the engine and app share no runtime
/// dependency on a UUID package.
String newUuidV4([Random? rng]) {
  final r = rng ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    int nibble;
    if (i == 12) {
      nibble = 4; // version 4
    } else if (i == 16) {
      nibble = 8 | (r.nextInt(4)); // variant 10xx → 8/9/a/b
    } else {
      nibble = r.nextInt(16);
    }
    buffer.write(_hex[nibble]);
    if (i == 7 || i == 11 || i == 15 || i == 19) buffer.write('-');
  }
  return buffer.toString();
}

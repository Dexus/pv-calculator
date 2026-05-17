import 'dart:convert';

/// Returns a stable, key-sorted JSON encoding of [value].
///
/// Maps are emitted with keys in sorted order so the resulting string is a
/// canonical form: two semantically equal configs (regardless of map insertion
/// order) produce the same bytes. Doubles use Dart's default `JsonEncoder`
/// repr, which is stable across runs of the same Dart VM. NaN/Infinity are
/// rejected by the underlying encoder.
String canonicalJsonEncode(Object? value) =>
    const JsonEncoder().convert(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    final out = <String, Object?>{};
    for (final k in keys) {
      out[k] = _canonicalize(value[k]);
    }
    return out;
  }
  if (value is List) {
    return [for (final e in value) _canonicalize(e)];
  }
  return value;
}

/// 64-bit FNV-1a hash of [input], returned as a lowercase 16-character hex
/// string. Used as the engine's input-hash fingerprint for reproducibility
/// (PRD NFR-05). FNV-1a is intentionally non-cryptographic — it is fast,
/// has zero runtime dependencies (the engine forbids them), and is good
/// enough as a cache/equality key for canonical-JSON inputs.
///
/// Implemented over [BigInt] so the result is correct on every Dart target,
/// including JS/web where native `int` is a 53-bit double and would lose
/// precision in the 64-bit multiply.
String fnv1a64Hex(String input) {
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  for (final b in utf8.encode(input)) {
    hash = (hash ^ BigInt.from(b)) & mask;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// Pure-Dart catalog of PV components used to prefill calculator input
/// forms. See README.md for the design rationale.
library;

import 'dart:convert';

/// Coarse classification of a catalog entry. Used for filtering and for
/// the JSON discriminator.
enum ComponentKind { module, inverter, battery }

String _kindName(ComponentKind k) => switch (k) {
      ComponentKind.module => 'module',
      ComponentKind.inverter => 'inverter',
      ComponentKind.battery => 'battery',
    };

ComponentKind _kindFromName(String s) => switch (s) {
      'module' => ComponentKind.module,
      'inverter' => ComponentKind.inverter,
      'battery' => ComponentKind.battery,
      _ => throw ArgumentError('Unknown ComponentKind: $s'),
    };

/// Inverter role in the catalog. Mirrors `pv_engine.InverterRole` 1:1
/// but stays local so this package depends on no other package.
enum CatalogInverterRole { grid, batteryCoupled, microInverter800W }

String _roleName(CatalogInverterRole r) => switch (r) {
      CatalogInverterRole.grid => 'grid',
      CatalogInverterRole.batteryCoupled => 'batteryCoupled',
      CatalogInverterRole.microInverter800W => 'microInverter800W',
    };

CatalogInverterRole _roleFromName(String s) => switch (s) {
      'grid' => CatalogInverterRole.grid,
      'batteryCoupled' => CatalogInverterRole.batteryCoupled,
      'microInverter800W' => CatalogInverterRole.microInverter800W,
      _ => throw ArgumentError('Unknown CatalogInverterRole: $s'),
    };

/// Base class for every catalog entry. Each subclass provides the
/// kind-specific fields plus its own `toJson()` / `fromJson()`.
sealed class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.manufacturer,
    required this.model,
    this.sourceUrl,
    this.notes,
  });

  final String id;
  final String manufacturer;
  final String model;
  final String? sourceUrl;
  final String? notes;

  ComponentKind get kind;

  String get displayName => '$manufacturer $model'.trim();

  Map<String, dynamic> toJson();

  /// Throws `ArgumentError` if any invariant is violated.
  void validate();

  /// Dispatch factory keyed on `kind`.
  static CatalogEntry fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind'];
    if (kindRaw is! String) {
      throw ArgumentError('Catalog entry missing string `kind` field.');
    }
    switch (_kindFromName(kindRaw)) {
      case ComponentKind.module:
        return ModuleCatalogEntry.fromJson(json);
      case ComponentKind.inverter:
        return InverterCatalogEntry.fromJson(json);
      case ComponentKind.battery:
        return BatteryCatalogEntry.fromJson(json);
    }
  }
}

class ModuleCatalogEntry extends CatalogEntry {
  const ModuleCatalogEntry({
    required super.id,
    required super.manufacturer,
    required super.model,
    required this.peakKwPerModule,
    this.cellTechnology,
    this.temperatureCoefficientPctPerC = 0.0,
    this.nominalOperatingCellTempC = 45.0,
    this.degradationPctPerYear = 0.0,
    super.sourceUrl,
    super.notes,
  });

  /// Module-level peak power, in kWp. The form layer multiplies by the
  /// user-supplied count to populate `PvArray.peakKw`.
  final double peakKwPerModule;
  final String? cellTechnology;
  final double temperatureCoefficientPctPerC;
  final double nominalOperatingCellTempC;
  final double degradationPctPerYear;

  @override
  ComponentKind get kind => ComponentKind.module;

  @override
  void validate() {
    if (id.isEmpty) throw ArgumentError('ModuleCatalogEntry.id must be non-empty');
    if (peakKwPerModule <= 0) {
      throw ArgumentError('ModuleCatalogEntry.peakKwPerModule must be > 0');
    }
    if (degradationPctPerYear < 0 || degradationPctPerYear >= 10) {
      throw ArgumentError(
          'ModuleCatalogEntry.degradationPctPerYear must be in [0, 10)');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': _kindName(kind),
        'id': id,
        'manufacturer': manufacturer,
        'model': model,
        'peakKwPerModule': peakKwPerModule,
        if (cellTechnology != null) 'cellTechnology': cellTechnology,
        'temperatureCoefficientPctPerC': temperatureCoefficientPctPerC,
        'nominalOperatingCellTempC': nominalOperatingCellTempC,
        if (degradationPctPerYear != 0.0)
          'degradationPctPerYear': degradationPctPerYear,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (notes != null) 'notes': notes,
      };

  factory ModuleCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ModuleCatalogEntry(
      id: json['id'] as String,
      manufacturer: json['manufacturer'] as String,
      model: json['model'] as String,
      peakKwPerModule: (json['peakKwPerModule'] as num).toDouble(),
      cellTechnology: json['cellTechnology'] as String?,
      temperatureCoefficientPctPerC:
          (json['temperatureCoefficientPctPerC'] as num?)?.toDouble() ?? 0.0,
      nominalOperatingCellTempC:
          (json['nominalOperatingCellTempC'] as num?)?.toDouble() ?? 45.0,
      degradationPctPerYear:
          (json['degradationPctPerYear'] as num?)?.toDouble() ?? 0.0,
      sourceUrl: json['sourceUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class InverterCatalogEntry extends CatalogEntry {
  const InverterCatalogEntry({
    required super.id,
    required super.manufacturer,
    required super.model,
    required this.maxAcKw,
    this.maxDcInputKw,
    this.efficiency = 0.965,
    this.role = CatalogInverterRole.grid,
    super.sourceUrl,
    super.notes,
  });

  final double maxAcKw;
  final double? maxDcInputKw;
  final double efficiency;
  final CatalogInverterRole role;

  @override
  ComponentKind get kind => ComponentKind.inverter;

  @override
  void validate() {
    if (id.isEmpty) throw ArgumentError('InverterCatalogEntry.id must be non-empty');
    if (maxAcKw <= 0) {
      throw ArgumentError('InverterCatalogEntry.maxAcKw must be > 0');
    }
    if (efficiency <= 0 || efficiency > 1) {
      throw ArgumentError('InverterCatalogEntry.efficiency must be in (0, 1]');
    }
    if (maxDcInputKw != null && maxDcInputKw! <= 0) {
      throw ArgumentError('InverterCatalogEntry.maxDcInputKw must be > 0');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': _kindName(kind),
        'id': id,
        'manufacturer': manufacturer,
        'model': model,
        'maxAcKw': maxAcKw,
        if (maxDcInputKw != null) 'maxDcInputKw': maxDcInputKw,
        'efficiency': efficiency,
        'role': _roleName(role),
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (notes != null) 'notes': notes,
      };

  factory InverterCatalogEntry.fromJson(Map<String, dynamic> json) {
    return InverterCatalogEntry(
      id: json['id'] as String,
      manufacturer: json['manufacturer'] as String,
      model: json['model'] as String,
      maxAcKw: (json['maxAcKw'] as num).toDouble(),
      maxDcInputKw: (json['maxDcInputKw'] as num?)?.toDouble(),
      efficiency: (json['efficiency'] as num?)?.toDouble() ?? 0.965,
      role: json['role'] is String
          ? _roleFromName(json['role'] as String)
          : CatalogInverterRole.grid,
      sourceUrl: json['sourceUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class BatteryCatalogEntry extends CatalogEntry {
  const BatteryCatalogEntry({
    required super.id,
    required super.manufacturer,
    required super.model,
    required this.capacityKwh,
    required this.maxChargeKw,
    required this.maxDischargeKw,
    this.chemistry,
    this.roundTripEfficiency = 0.9,
    this.minSocKwh = 0.0,
    super.sourceUrl,
    super.notes,
  });

  final double capacityKwh;
  final double maxChargeKw;
  final double maxDischargeKw;
  final String? chemistry;
  final double roundTripEfficiency;
  final double minSocKwh;

  @override
  ComponentKind get kind => ComponentKind.battery;

  @override
  void validate() {
    if (id.isEmpty) throw ArgumentError('BatteryCatalogEntry.id must be non-empty');
    if (capacityKwh <= 0) {
      throw ArgumentError('BatteryCatalogEntry.capacityKwh must be > 0');
    }
    if (maxChargeKw <= 0 || maxDischargeKw <= 0) {
      throw ArgumentError(
          'BatteryCatalogEntry charge/discharge rates must be > 0');
    }
    if (roundTripEfficiency <= 0 || roundTripEfficiency > 1) {
      throw ArgumentError(
          'BatteryCatalogEntry.roundTripEfficiency must be in (0, 1]');
    }
    if (minSocKwh < 0 || minSocKwh >= capacityKwh) {
      throw ArgumentError(
          'BatteryCatalogEntry.minSocKwh must be in [0, capacityKwh)');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': _kindName(kind),
        'id': id,
        'manufacturer': manufacturer,
        'model': model,
        'capacityKwh': capacityKwh,
        'maxChargeKw': maxChargeKw,
        'maxDischargeKw': maxDischargeKw,
        if (chemistry != null) 'chemistry': chemistry,
        'roundTripEfficiency': roundTripEfficiency,
        if (minSocKwh != 0.0) 'minSocKwh': minSocKwh,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (notes != null) 'notes': notes,
      };

  factory BatteryCatalogEntry.fromJson(Map<String, dynamic> json) {
    return BatteryCatalogEntry(
      id: json['id'] as String,
      manufacturer: json['manufacturer'] as String,
      model: json['model'] as String,
      capacityKwh: (json['capacityKwh'] as num).toDouble(),
      maxChargeKw: (json['maxChargeKw'] as num).toDouble(),
      maxDischargeKw: (json['maxDischargeKw'] as num).toDouble(),
      chemistry: json['chemistry'] as String?,
      roundTripEfficiency:
          (json['roundTripEfficiency'] as num?)?.toDouble() ?? 0.9,
      minSocKwh: (json['minSocKwh'] as num?)?.toDouble() ?? 0.0,
      sourceUrl: json['sourceUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// Abstract source of catalog entries. Read-only sources (the bundled
/// seed, future remote APIs) leave `isWritable` at false and inherit
/// `upsert`/`delete` from the base which throws `UnsupportedError`.
abstract class CatalogSource {
  const CatalogSource();

  /// Returns the full list of entries this source can produce.
  Future<List<CatalogEntry>> fetch();

  /// Whether [upsert] and [delete] are supported.
  bool get isWritable => false;

  /// Insert or update an entry. Throws `UnsupportedError` on read-only
  /// sources.
  Future<void> upsert(CatalogEntry entry) =>
      throw UnsupportedError('Source is read-only.');

  /// Remove an entry by id. Throws `UnsupportedError` on read-only
  /// sources.
  Future<void> delete(String id) =>
      throw UnsupportedError('Source is read-only.');
}

/// In-memory source useful for tests and hard-coded fallbacks.
class InMemoryCatalogSource extends CatalogSource {
  InMemoryCatalogSource(Iterable<CatalogEntry> entries, {bool writable = true})
      : _entries = {for (final e in entries) e.id: e},
        _writable = writable;

  final Map<String, CatalogEntry> _entries;
  final bool _writable;

  @override
  bool get isWritable => _writable;

  @override
  Future<List<CatalogEntry>> fetch() async => _entries.values.toList();

  @override
  Future<void> upsert(CatalogEntry entry) async {
    if (!_writable) {
      throw UnsupportedError('InMemoryCatalogSource is read-only.');
    }
    entry.validate();
    _entries[entry.id] = entry;
  }

  @override
  Future<void> delete(String id) async {
    if (!_writable) {
      throw UnsupportedError('InMemoryCatalogSource is read-only.');
    }
    _entries.remove(id);
  }
}

/// Combines a list of [CatalogSource]s in priority order. Sources later
/// in the list **override** earlier ones on `id` collision — so callers
/// typically pass `[seed, userOverrides]` to let user-added entries
/// shadow the bundled defaults.
class MergedCatalog {
  MergedCatalog(this.sources);

  final List<CatalogSource> sources;

  List<CatalogEntry>? _cache;

  /// Drops the memoised entry list so the next [all] call re-fetches.
  void invalidate() => _cache = null;

  Future<List<CatalogEntry>> all() async {
    final cached = _cache;
    if (cached != null) return cached;
    final merged = <String, CatalogEntry>{};
    for (final src in sources) {
      for (final entry in await src.fetch()) {
        merged[entry.id] = entry;
      }
    }
    // Unmodifiable view so callers can't corrupt the memoised cache
    // by mutating the returned list. Entries themselves are immutable
    // value classes, so a shallow guard is sufficient.
    final list = List<CatalogEntry>.unmodifiable(merged.values);
    _cache = list;
    return list;
  }

  Future<List<T>> byKind<T extends CatalogEntry>(ComponentKind kind) async {
    final entries = await all();
    return entries.whereType<T>().where((e) => e.kind == kind).toList();
  }
}

/// Parses the bundled seed-catalog document shape
/// `{ "version": 1, "modules": [...], "inverters": [...], "batteries": [...] }`
/// into a flat `List<CatalogEntry>`. The discriminator on each entry is
/// inferred from the section it appears in (the section name is the
/// authoritative source; an explicit `kind` on the JSON object is also
/// accepted for forward-compatibility with mixed-section dumps).
/// The seed-catalog versions this parser understands. Bump when the
/// document shape changes incompatibly (e.g. renamed sections, removed
/// required fields). Forward-compatible field additions on entries
/// are absorbed silently by the per-entry `fromJson` factories.
const Set<int> kSupportedSeedCatalogVersions = {1};

List<CatalogEntry> parseSeedCatalog(String jsonText) {
  final raw = jsonDecode(jsonText);
  if (raw is! Map<String, dynamic>) {
    throw ArgumentError('Seed catalog must be a JSON object.');
  }
  final version = raw['version'];
  if (version is! int) {
    throw ArgumentError(
        'Seed catalog must declare an integer `version` field.');
  }
  if (!kSupportedSeedCatalogVersions.contains(version)) {
    throw ArgumentError(
        'Unsupported seed catalog version: $version '
        '(supported: $kSupportedSeedCatalogVersions).');
  }
  final out = <CatalogEntry>[];
  for (final section in const [
    (ComponentKind.module, 'modules'),
    (ComponentKind.inverter, 'inverters'),
    (ComponentKind.battery, 'batteries'),
  ]) {
    final list = raw[section.$2];
    if (list == null) continue;
    if (list is! List) {
      throw ArgumentError('Seed section ${section.$2} must be a JSON list.');
    }
    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        throw ArgumentError(
            'Entries in ${section.$2} must be JSON objects.');
      }
      final withKind = {...item, 'kind': _kindName(section.$1)};
      final entry = CatalogEntry.fromJson(withKind);
      entry.validate();
      out.add(entry);
    }
  }
  return out;
}

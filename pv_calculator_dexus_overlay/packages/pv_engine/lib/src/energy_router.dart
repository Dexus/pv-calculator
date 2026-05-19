import 'dart:math' as math;

import 'dispatch_policy.dart';
import 'micro_inverter_bank.dart';

/// Result of applying a [DispatchPlan] to the current battery state for
/// one step. All energies are AC kWh on the household bus unless noted.
class RoutedFlows {
  const RoutedFlows({
    required this.batteryChargesKwh,
    required this.batteryDischargesKwh,
    required this.bankDeliveriesKwh,
    required this.bankShortfallsKwh,
    required this.selfConsumptionKwh,
    required this.gridImportKwh,
    required this.gridExportKwh,
    required this.curtailedExportKwh,
    required this.unservedLoadKwh,
    required this.batterySocsKwh,
  });

  final List<double> batteryChargesKwh;
  final List<double> batteryDischargesKwh;
  final List<double> bankDeliveriesKwh;
  final List<double> bankShortfallsKwh;
  final double selfConsumptionKwh;
  final double gridImportKwh;
  final double gridExportKwh;
  final double curtailedExportKwh;
  final double unservedLoadKwh;
  final List<double> batterySocsKwh;
}

class EnergyRouter {
  const EnergyRouter();

  /// Apply a dispatch [plan] to the per-step state. Mutates the [socs]
  /// list in place (carrying SOC across steps is the simulator's job).
  ///
  /// Order of operations:
  ///   1. Charge each battery from PV surplus (enforce rate +
  ///      headroom). Batteries listed in [skipChargeIndices] are
  ///      skipped here — they are DC-coupled and have already been
  ///      charged from the DC bus by the simulator before this call.
  ///   2. Direct-discharge each battery towards remaining household
  ///      load (enforce rate + usable SOC).
  ///   3. Run each micro-inverter bank, draining its source battery
  ///      (enforce rate + SOC shutdown + remaining DC headroom).
  ///   4. Bank AC output covers remaining load first, then exports.
  ///   5. PV surplus that didn't fit anywhere becomes grid export
  ///      (capped) or curtailment.
  ///   6. Remaining load either imports from grid or accrues as
  ///      `unservedLoadKwh`, per the plan's `allowGridImport` flag.
  RoutedFlows apply({
    required DispatchPlan plan,
    required List<double> socs,
    required List<double> capacitiesKwh,
    required List<double> minSocsKwh,
    required List<double> maxChargeKw,
    required List<double> maxDischargeKw,
    required List<double> chargeEfficiency,
    required List<double> dischargeEfficiency,
    required List<String> batteryIds,
    required List<MicroInverterBank> banks,
    required double pvAcKwh,
    required double loadKwh,
    required double stepHours,
    required double? gridExportLimitKw,
    List<double>? batteryAcCapKwh,
    Set<int> skipChargeIndices = const {},
  }) {
    final n = batteryIds.length;
    final batteryById = {for (var i = 0; i < n; i++) batteryIds[i]: i};

    final actualCharge = List<double>.filled(n, 0.0);
    final actualDirectDischarge = List<double>.filled(n, 0.0);

    var surplus = math.max(0.0, pvAcKwh - loadKwh);
    var remainingLoad = math.max(0.0, loadKwh - pvAcKwh);
    var selfConsumption = math.min(pvAcKwh, loadKwh);

    // Step 1: Charge from PV surplus.
    for (var i = 0; i < n; i++) {
      if (surplus <= 0) break;
      if (i >= plan.batteryChargeRequestsKwh.length) break;
      // DC-coupled batteries were already charged from the DC bus by
      // `_simulateStep` before this call — skip AC charging for them so
      // the same energy is not double-counted on the input side and so
      // the battery's own rate cap stays correct.
      if (skipChargeIndices.contains(i)) continue;
      final requested = math.max(0.0, plan.batteryChargeRequestsKwh[i]);
      if (requested <= 0) continue;
      final headroomStored = math.max(0.0, capacitiesKwh[i] - socs[i]);
      final headroomAc = chargeEfficiency[i] == 0 ? 0.0 : headroomStored / chargeEfficiency[i];
      final rateCap = maxChargeKw[i] * stepHours;
      final ackKwh = math.min(requested, math.min(math.min(surplus, rateCap), headroomAc));
      if (ackKwh <= 0) continue;
      actualCharge[i] = ackKwh;
      socs[i] += ackKwh * chargeEfficiency[i];
      surplus -= ackKwh;
    }

    // Step 2: Direct (non-bank) discharge → remaining load.
    // Cap by the battery's AC envelope per Architektur §5.3 — the
    // inverter limit (when topology supplies one) is the AC ceiling
    // shared by direct discharge and banks; otherwise fall back to
    // `maxDischargeKw` so legacy projects keep their numbers.
    for (var i = 0; i < n; i++) {
      if (remainingLoad <= 0) break;
      if (i >= plan.batteryDirectDischargeRequestsKwh.length) break;
      final requested = math.max(0.0, plan.batteryDirectDischargeRequestsKwh[i]);
      if (requested <= 0) continue;
      final usableStored = math.max(0.0, socs[i] - minSocsKwh[i]);
      final usableAc = usableStored * dischargeEfficiency[i];
      final acCap = batteryAcCapKwh != null && i < batteryAcCapKwh.length
          ? batteryAcCapKwh[i]
          : maxDischargeKw[i] * stepHours;
      final acKwh = math.min(requested, math.min(math.min(remainingLoad, acCap), usableAc));
      if (acKwh <= 0) continue;
      actualDirectDischarge[i] = acKwh;
      socs[i] -= dischargeEfficiency[i] == 0 ? 0 : acKwh / dischargeEfficiency[i];
      remainingLoad -= acKwh;
      selfConsumption += acKwh;
    }

    // Step 3: Banks — each pulls from its source battery and delivers AC.
    final bankDeliveries = List<double>.filled(banks.length, 0.0);
    final bankShortfalls = List<double>.filled(banks.length, 0.0);

    // Per-battery cumulative AC kWh already drawn this step (direct
    // discharge in Step 2 plus prior banks). Used to honour the battery
    // rate cap when multiple banks share one source battery.
    final batteryAcUsed = List<double>.from(actualDirectDischarge);

    for (var b = 0; b < banks.length; b++) {
      final bank = banks[b];
      final requested = plan.bankDeliveryRequestsKwh[bank.id] ?? 0.0;
      final targetKwh = math.max(0.0, requested);
      if (targetKwh <= 0) continue;
      final battIdx = batteryById[bank.batteryId];
      if (battIdx == null) {
        // Misconfigured topology — surface as full shortfall rather
        // than crashing the simulator. Validation should have caught it.
        bankShortfalls[b] = targetKwh;
        continue;
      }
      final socFraction = capacitiesKwh[battIdx] <= 0 ? 0.0 : socs[battIdx] / capacitiesKwh[battIdx];
      if (socFraction <= bank.minSocShutdown) {
        bankShortfalls[b] = targetKwh;
        continue;
      }
      // Bank-internal inverter loss: DC kWh withdrawn from battery =
      // AC delivered / bank.inverterEfficiency. Battery-internal
      // discharge eta is applied separately on the SOC update.
      final acRateCap = bank.count * bank.unitRatedPowerW / 1000.0 * stepHours;
      final usableStored = math.max(0.0, socs[battIdx] - minSocsKwh[battIdx]);
      final acFromStored = usableStored *
          dischargeEfficiency[battIdx] *
          bank.inverterEfficiency;
      // Remaining headroom on this battery's AC discharge cap, after
      // direct-discharge and any earlier banks in declared order.
      // When `batteryAcCapKwh` is supplied (Phase-4 topology with an
      // explicit battery inverter) it overrides `maxDischargeKw` per
      // Architektur §5.3 `inverterLimitW`; otherwise fall back to the
      // legacy battery-rate cap so pre-topology projects keep their
      // existing dispatch numbers.
      //
      // DC-coupled batteries (`skipChargeIndices`) are special: the
      // bus-inverter cap in `batteryAcCapKwh` is the *direct-discharge*
      // path only — banks have their own AC stage and bypass the bus
      // inverter entirely, so they use `maxDischargeKw` (the battery's
      // DC rate cap) regardless of whether a bus inverter is wired.
      final acCap = skipChargeIndices.contains(battIdx)
          ? maxDischargeKw[battIdx] * stepHours
          : (batteryAcCapKwh != null && battIdx < batteryAcCapKwh.length
              ? batteryAcCapKwh[battIdx]
              : maxDischargeKw[battIdx] * stepHours);
      final battAcRemaining =
          math.max(0.0, acCap - batteryAcUsed[battIdx]);
      final battRateAc = battAcRemaining * bank.inverterEfficiency;
      final delivered = math.min(targetKwh, math.min(math.min(acRateCap, acFromStored), battRateAc));
      if (delivered <= 0) {
        bankShortfalls[b] = targetKwh;
        continue;
      }
      bankDeliveries[b] = delivered;
      bankShortfalls[b] = math.max(0.0, targetKwh - delivered);
      final storedWithdrawal = bank.inverterEfficiency == 0 || dischargeEfficiency[battIdx] == 0
          ? 0.0
          : delivered / bank.inverterEfficiency / dischargeEfficiency[battIdx];
      socs[battIdx] -= storedWithdrawal;
      // Track AC-equivalent draw against the battery's rate cap. We
      // count `delivered / inverterEfficiency` (the AC-side draw before
      // the bank's own inverter loss) so the cap holds in the same units
      // as `maxDischargeKw[i] * stepHours` used above.
      batteryAcUsed[battIdx] += bank.inverterEfficiency == 0
          ? 0.0
          : delivered / bank.inverterEfficiency;
    }

    // Step 4: Bank AC output → covers remaining load, then export.
    var bankAc = bankDeliveries.fold<double>(0.0, (s, v) => s + v);
    if (bankAc > 0 && remainingLoad > 0) {
      final used = math.min(bankAc, remainingLoad);
      remainingLoad -= used;
      bankAc -= used;
      selfConsumption += used;
    }

    // Step 5: PV surplus + leftover bank AC → grid export, with cap.
    var exportRequest = surplus + bankAc;
    var curtailedExport = 0.0;
    if (gridExportLimitKw != null) {
      final cap = gridExportLimitKw * stepHours;
      if (exportRequest > cap) {
        curtailedExport = exportRequest - cap;
        exportRequest = cap;
      }
    }

    // Step 6: Cover remaining load via grid import (or accrue as unserved).
    final import = plan.allowGridImport ? remainingLoad : 0.0;
    final unserved = plan.allowGridImport ? 0.0 : remainingLoad;

    // Clamp SOCs against bounds in case of fp drift.
    for (var i = 0; i < n; i++) {
      socs[i] = socs[i].clamp(minSocsKwh[i], capacitiesKwh[i]).toDouble();
    }

    return RoutedFlows(
      batteryChargesKwh: List<double>.unmodifiable(actualCharge),
      batteryDischargesKwh: List<double>.unmodifiable([
        for (var i = 0; i < n; i++) actualDirectDischarge[i] + _bankWithdrawalAc(
          batteryIndex: i,
          banks: banks,
          deliveries: bankDeliveries,
          dischargeEfficiency: dischargeEfficiency,
          batteryById: batteryById,
        ),
      ]),
      bankDeliveriesKwh: List<double>.unmodifiable(bankDeliveries),
      bankShortfallsKwh: List<double>.unmodifiable(bankShortfalls),
      selfConsumptionKwh: selfConsumption,
      gridImportKwh: import,
      gridExportKwh: exportRequest,
      curtailedExportKwh: curtailedExport,
      unservedLoadKwh: unserved,
      batterySocsKwh: List<double>.unmodifiable(socs),
    );
  }
}

/// Report the AC-equivalent energy this battery delivered via banks
/// this step. Banks store deliveries on the AC side; rebuilding the
/// per-battery total requires summing over all banks pointing at it.
double _bankWithdrawalAc({
  required int batteryIndex,
  required List<MicroInverterBank> banks,
  required List<double> deliveries,
  required List<double> dischargeEfficiency,
  required Map<String, int> batteryById,
}) {
  var sum = 0.0;
  for (var b = 0; b < banks.length; b++) {
    final battIdx = batteryById[banks[b].batteryId];
    if (battIdx == batteryIndex) {
      // Treat the bank AC as the discharge contribution from this
      // battery; the AC↔DC efficiency is bookkeeping inside the bank,
      // not double-counted here.
      sum += deliveries[b];
    }
  }
  return sum;
}

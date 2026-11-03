// Pure fuel and spending calculations (full-to-full method).
// Spec: MY_LOGAN_SPEC.md §3.

class FuelPurchaseInput {
  const FuelPurchaseInput({
    required this.id,
    required this.date,
    required this.liters,
    required this.totalPaidDh,
    required this.odometerKm,
    required this.isFullTank,
  });

  final int id;
  final DateTime date;
  final double liters;
  final double totalPaidDh;
  final double odometerKm;
  final bool isFullTank;
}

class FullTankInterval {
  const FullTankInterval({
    required this.startFullId,
    required this.endFullId,
    required this.distanceKm,
    required this.litersConsumed,
    required this.costDh,
  });

  final int startFullId;
  final int endFullId;
  final double distanceKm;
  final double litersConsumed;
  final double costDh;

  double get litersPer100Km =>
      distanceKm <= 0 ? double.nan : 100 * litersConsumed / distanceKm;

  double get costPerKm => distanceKm <= 0 ? double.nan : costDh / distanceKm;
}

class ConsumptionSummary {
  const ConsumptionSummary({
    required this.intervals,
    required this.averageLitersPer100Km,
    required this.averageCostPerKm,
  });

  final List<FullTankInterval> intervals;
  final double? averageLitersPer100Km;
  final double? averageCostPerKm;

  bool get hasReliableData =>
      intervals.isNotEmpty &&
      averageLitersPer100Km != null &&
      averageCostPerKm != null;
}

double dhPerLiter(double totalPaidDh, double liters) {
  if (liters <= 0) return double.nan;
  return totalPaidDh / liters;
}

double monthlyFuelSpending(Iterable<FuelPurchaseInput> purchases, int year, int month) {
  var sum = 0.0;
  for (final p in purchases) {
    if (p.date.year == year && p.date.month == month) {
      sum += p.totalPaidDh;
    }
  }
  return sum;
}

double monthlyLitersPurchased(Iterable<FuelPurchaseInput> purchases, int year, int month) {
  var sum = 0.0;
  for (final p in purchases) {
    if (p.date.year == year && p.date.month == month) {
      sum += p.liters;
    }
  }
  return sum;
}

int monthlyFuelingCount(Iterable<FuelPurchaseInput> purchases, int year, int month) {
  var count = 0;
  for (final p in purchases) {
    if (p.date.year == year && p.date.month == month) count++;
  }
  return count;
}

/// Builds non-overlapping full-to-full intervals.
/// Liters/cost for an interval = purchases AFTER start full through AND including end full.
/// The first full tank's liters/cost are excluded from that first interval.
List<FullTankInterval> computeFullTankIntervals(List<FuelPurchaseInput> purchases) {
  final ordered = [...purchases]
    ..sort((a, b) {
      final o = a.odometerKm.compareTo(b.odometerKm);
      if (o != 0) return o;
      final d = a.date.compareTo(b.date);
      if (d != 0) return d;
      return a.id.compareTo(b.id);
    });

  final fulls = ordered.where((p) => p.isFullTank).toList();
  if (fulls.length < 2) return const [];

  final intervals = <FullTankInterval>[];
  for (var i = 0; i < fulls.length - 1; i++) {
    final start = fulls[i];
    final end = fulls[i + 1];
    final distance = end.odometerKm - start.odometerKm;
    if (distance <= 0) continue;

    var liters = 0.0;
    var cost = 0.0;
    for (final p in ordered) {
      final afterStart = p.odometerKm > start.odometerKm ||
          (p.odometerKm == start.odometerKm &&
              (p.date.isAfter(start.date) ||
                  (p.date.isAtSameMomentAs(start.date) && p.id > start.id)));
      final upToEnd = p.odometerKm < end.odometerKm ||
          (p.odometerKm == end.odometerKm &&
              (p.date.isBefore(end.date) ||
                  (p.date.isAtSameMomentAs(end.date) && p.id <= end.id)));
      if (afterStart && upToEnd) {
        liters += p.liters;
        cost += p.totalPaidDh;
      }
    }

    // Ensure end full is included even if id/date edge cases differ.
    // Prefer id-window between consecutive fulls in ordered list.
    liters = 0.0;
    cost = 0.0;
    final startIndex = ordered.indexWhere((p) => p.id == start.id);
    final endIndex = ordered.indexWhere((p) => p.id == end.id);
    if (startIndex < 0 || endIndex < 0 || endIndex <= startIndex) continue;
    for (var j = startIndex + 1; j <= endIndex; j++) {
      liters += ordered[j].liters;
      cost += ordered[j].totalPaidDh;
    }

    intervals.add(
      FullTankInterval(
        startFullId: start.id,
        endFullId: end.id,
        distanceKm: distance,
        litersConsumed: liters,
        costDh: cost,
      ),
    );
  }
  return intervals;
}

ConsumptionSummary summarizeConsumption(List<FuelPurchaseInput> purchases) {
  final intervals = computeFullTankIntervals(purchases);
  if (intervals.isEmpty) {
    return const ConsumptionSummary(
      intervals: [],
      averageLitersPer100Km: null,
      averageCostPerKm: null,
    );
  }

  var totalLiters = 0.0;
  var totalDistance = 0.0;
  var totalCost = 0.0;
  for (final i in intervals) {
    totalLiters += i.litersConsumed;
    totalDistance += i.distanceKm;
    totalCost += i.costDh;
  }

  if (totalDistance <= 0) {
    return ConsumptionSummary(
      intervals: intervals,
      averageLitersPer100Km: null,
      averageCostPerKm: null,
    );
  }

  return ConsumptionSummary(
    intervals: intervals,
    averageLitersPer100Km: 100 * totalLiters / totalDistance,
    averageCostPerKm: totalCost / totalDistance,
  );
}

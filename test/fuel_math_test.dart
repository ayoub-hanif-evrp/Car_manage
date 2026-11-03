import 'package:flutter_test/flutter_test.dart';
import 'package:my_logan/calc/fuel_math.dart';

void main() {
  group('full-to-full consumption', () {
    test('500 km / 35 L / 420 DH => 7.0 L/100km and 0.84 DH/km', () {
      final purchases = [
        FuelPurchaseInput(
          id: 1,
          date: DateTime(2024, 1, 1),
          liters: 40,
          totalPaidDh: 500,
          odometerKm: 150000,
          isFullTank: true,
        ),
        FuelPurchaseInput(
          id: 2,
          date: DateTime(2024, 1, 15),
          liters: 35,
          totalPaidDh: 420,
          odometerKm: 150500,
          isFullTank: true,
        ),
      ];

      final summary = summarizeConsumption(purchases);
      expect(summary.hasReliableData, isTrue);
      expect(summary.intervals, hasLength(1));
      expect(summary.intervals.first.distanceKm, 500);
      expect(summary.intervals.first.litersConsumed, 35);
      expect(summary.averageLitersPer100Km!, closeTo(7.0, 0.001));
      expect(summary.averageCostPerKm!, closeTo(0.84, 0.001));
    });

    test('intermediate 10 L + second fill 25 L uses 35 L', () {
      final purchases = [
        FuelPurchaseInput(
          id: 1,
          date: DateTime(2024, 1, 1),
          liters: 40,
          totalPaidDh: 480,
          odometerKm: 100000,
          isFullTank: true,
        ),
        FuelPurchaseInput(
          id: 2,
          date: DateTime(2024, 1, 10),
          liters: 10,
          totalPaidDh: 120,
          odometerKm: 100200,
          isFullTank: false,
        ),
        FuelPurchaseInput(
          id: 3,
          date: DateTime(2024, 1, 20),
          liters: 25,
          totalPaidDh: 300,
          odometerKm: 100500,
          isFullTank: true,
        ),
      ];

      final intervals = computeFullTankIntervals(purchases);
      expect(intervals, hasLength(1));
      expect(intervals.first.litersConsumed, 35);
      expect(intervals.first.distanceKm, 500);
    });

    test('monthly fuel spending sums purchase amounts', () {
      final purchases = [
        FuelPurchaseInput(
          id: 1,
          date: DateTime(2024, 3, 2),
          liters: 10,
          totalPaidDh: 200,
          odometerKm: 1,
          isFullTank: false,
        ),
        FuelPurchaseInput(
          id: 2,
          date: DateTime(2024, 3, 12),
          liters: 15,
          totalPaidDh: 300,
          odometerKm: 2,
          isFullTank: false,
        ),
        FuelPurchaseInput(
          id: 3,
          date: DateTime(2024, 3, 22),
          liters: 12,
          totalPaidDh: 250,
          odometerKm: 3,
          isFullTank: false,
        ),
      ];
      expect(monthlyFuelSpending(purchases, 2024, 3), 750);
    });

    test('single full tank is not enough data', () {
      final purchases = [
        FuelPurchaseInput(
          id: 1,
          date: DateTime(2024, 1, 1),
          liters: 40,
          totalPaidDh: 500,
          odometerKm: 1000,
          isFullTank: true,
        ),
      ];
      expect(summarizeConsumption(purchases).hasReliableData, isFalse);
    });
  });
}

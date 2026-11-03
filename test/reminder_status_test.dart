import 'package:flutter_test/flutter_test.dart';
import 'package:my_logan/data/models.dart';

void main() {
  group('ReminderEntry.status', () {
    final today = DateTime(2026, 11, 3);

    test('upcoming when due date is far ahead', () {
      final r = ReminderEntry(
        id: 1,
        kind: ReminderKind.insurance,
        dueDate: DateTime(2026, 12, 1),
        leadDays: 7,
      );
      expect(r.status(today: today), ReminderStatus.upcoming);
    });

    test('due within lead days', () {
      final r = ReminderEntry(
        id: 1,
        kind: ReminderKind.vignette,
        dueDate: DateTime(2026, 11, 8),
        leadDays: 7,
      );
      expect(r.status(today: today), ReminderStatus.due);
    });

    test('overdue after due date', () {
      final r = ReminderEntry(
        id: 1,
        kind: ReminderKind.visiteTechnique,
        dueDate: DateTime(2026, 11, 1),
        leadDays: 7,
      );
      expect(r.status(today: today), ReminderStatus.overdue);
    });

    test('odometer overdue and due window', () {
      final r = ReminderEntry(
        id: 1,
        kind: ReminderKind.oilChange,
        dueOdometerKm: 160000,
      );
      expect(
        r.status(today: today, latestOdometerKm: 160100),
        ReminderStatus.overdue,
      );
      expect(
        r.status(today: today, latestOdometerKm: 159600),
        ReminderStatus.due,
      );
      expect(
        r.status(today: today, latestOdometerKm: 159000),
        ReminderStatus.upcoming,
      );
    });
  });

  group('ReminderEntry.renew', () {
    test('applies month and km intervals', () {
      final r = ReminderEntry(
        id: 1,
        kind: ReminderKind.oilChange,
        dueDate: DateTime(2026, 5, 1),
        dueOdometerKm: 155000,
        intervalMonths: 6,
        intervalKm: 10000,
        leadDays: 14,
      );

      final next = r.renew(
        completedAt: DateTime(2026, 11, 3),
        completedOdometerKm: 158000,
      );

      expect(next.lastCompletedDate, DateTime(2026, 11, 3));
      expect(next.lastCompletedOdometerKm, 158000);
      expect(next.dueDate, DateTime(2027, 5, 3));
      expect(next.dueOdometerKm, 168000);
      expect(next.intervalMonths, 6);
      expect(next.intervalKm, 10000);
      expect(next.leadDays, 14);
    });

    test('clears dues when no interval configured', () {
      final r = ReminderEntry(
        id: 2,
        kind: ReminderKind.insurance,
        dueDate: DateTime(2026, 11, 1),
      );
      final next = r.renew(completedAt: DateTime(2026, 11, 3));
      expect(next.dueDate, isNull);
      expect(next.dueOdometerKm, isNull);
      expect(next.lastCompletedDate, DateTime(2026, 11, 3));
    });
  });
}

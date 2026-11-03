import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _ready = true;
  }

  Future<void> syncReminders(List<ReminderEntry> reminders) async {
    if (!_ready) await init();
    await _plugin.cancelAll();

    for (final r in reminders) {
      if (r.dueDate == null) continue;
      final notifyAt = DateTime(
        r.dueDate!.year,
        r.dueDate!.month,
        r.dueDate!.day,
      ).subtract(Duration(days: r.leadDays));

      var when = DateTime(notifyAt.year, notifyAt.month, notifyAt.day, 9);
      if (when.isBefore(DateTime.now())) {
        // Still notify on due morning if lead day already passed.
        when = DateTime(r.dueDate!.year, r.dueDate!.month, r.dueDate!.day, 9);
      }
      if (when.isBefore(DateTime.now())) continue;

      await _plugin.zonedSchedule(
        r.id,
        'My Logan · ${r.kind.labelFr}',
        'Échéance le ${r.dueDate!.day.toString().padLeft(2, '0')}/'
            '${r.dueDate!.month.toString().padLeft(2, '0')}/'
            '${r.dueDate!.year}',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_logan_reminders',
            'Reminders',
            channelDescription: 'Oil, insurance, vignette, visite technique',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Fire once when a newly recorded odometer crosses a mileage due target.
  Future<void> notifyOdometerCrossings({
    required List<ReminderEntry> reminders,
    required double? previousOdometerKm,
    required double? currentOdometerKm,
  }) async {
    if (currentOdometerKm == null) return;
    if (!_ready) await init();

    for (final r in reminders) {
      final due = r.dueOdometerKm;
      if (due == null) continue;
      final wasBelow = previousOdometerKm == null || previousOdometerKm < due;
      final nowAtOrOver = currentOdometerKm >= due;
      if (!wasBelow || !nowAtOrOver) continue;

      await _plugin.show(
        1000 + r.id,
        'My Logan · ${r.kind.labelFr}',
        'Odometer reached ${due.toStringAsFixed(0)} km '
            '(now ${currentOdometerKm.toStringAsFixed(0)} km)',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_logan_reminders',
            'Reminders',
            channelDescription: 'Oil, insurance, vignette, visite technique',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    }
  }
}

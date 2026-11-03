import 'package:flutter/foundation.dart';

import '../calc/fuel_math.dart';
import '../data/app_database.dart';
import '../data/models.dart';
import '../features/navigation/darija_voice_player.dart';
import '../features/navigation/navigation_service.dart';
import '../features/reminders/notification_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    AppDatabase? database,
    NotificationService? notifications,
    NavigationService? navigation,
    DarijaVoicePlayer? voice,
  })  : _db = database ?? AppDatabase.instance,
        _notifications = notifications ?? NotificationService.instance,
        navigation = navigation ?? OpenMapNavigationService(),
        voice = voice ?? DarijaVoicePlayer();

  final AppDatabase _db;
  final NotificationService _notifications;
  final NavigationService navigation;
  final DarijaVoicePlayer voice;

  bool loading = true;
  String? error;

  List<FuelEntry> fuelEntries = const [];
  List<RepairEntry> repairs = const [];
  List<ReminderEntry> reminders = const [];
  List<FavoritePlace> favorites = const [];
  List<RecentDestination> recentDestinations = const [];

  DateTime dashboardMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _notifications.init();
      fuelEntries = await _db.getFuelEntries();
      repairs = await _db.getRepairs();
      reminders = await _db.getReminders();
      favorites = await _db.getFavorites();
      recentDestinations = await _db.getRecents();
      await _notifications.syncReminders(reminders);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  ConsumptionSummary get consumption => summarizeConsumption(
        fuelEntries
            .map(
              (e) => FuelPurchaseInput(
                id: e.id,
                date: e.date,
                liters: e.liters,
                totalPaidDh: e.totalPaidDh,
                odometerKm: e.odometerKm,
                isFullTank: e.isFullTank,
              ),
            )
            .toList(),
      );

  double? get latestOdometer {
    if (fuelEntries.isEmpty) return null;
    return fuelEntries.map((e) => e.odometerKm).reduce((a, b) => a > b ? a : b);
  }

  double monthFuelSpend(DateTime month) => monthlyFuelSpending(
        fuelEntries.map(
          (e) => FuelPurchaseInput(
            id: e.id,
            date: e.date,
            liters: e.liters,
            totalPaidDh: e.totalPaidDh,
            odometerKm: e.odometerKm,
            isFullTank: e.isFullTank,
          ),
        ),
        month.year,
        month.month,
      );

  int monthFuelCount(DateTime month) => monthlyFuelingCount(
        fuelEntries.map(
          (e) => FuelPurchaseInput(
            id: e.id,
            date: e.date,
            liters: e.liters,
            totalPaidDh: e.totalPaidDh,
            odometerKm: e.odometerKm,
            isFullTank: e.isFullTank,
          ),
        ),
        month.year,
        month.month,
      );

  double monthRepairSpend(DateTime month) {
    var sum = 0.0;
    for (final r in repairs) {
      if (r.date.year == month.year && r.date.month == month.month) {
        sum += r.totalPriceDh;
      }
    }
    return sum;
  }

  double get lifetimeSpend {
    var sum = 0.0;
    for (final f in fuelEntries) {
      sum += f.totalPaidDh;
    }
    for (final r in repairs) {
      sum += r.totalPriceDh;
    }
    return sum;
  }

  List<({DateTime month, double fuel, double repairs})> lastMonths({int count = 6}) {
    final now = DateTime.now();
    final out = <({DateTime month, double fuel, double repairs})>[];
    for (var i = count - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      out.add((
        month: m,
        fuel: monthFuelSpend(m),
        repairs: monthRepairSpend(m),
      ));
    }
    return out;
  }

  List<RecentTransaction> recentTransactions({int limit = 8}) {
    final items = <RecentTransaction>[
      ...fuelEntries.map(
        (e) => RecentTransaction(
          date: e.date,
          label: e.station?.isNotEmpty == true ? 'Fuel · ${e.station}' : 'Fuel',
          amountDh: e.totalPaidDh,
          isFuel: true,
        ),
      ),
      ...repairs.map(
        (e) => RecentTransaction(
          date: e.date,
          label: e.description,
          amountDh: e.totalPriceDh,
          isFuel: false,
        ),
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return items.take(limit).toList();
  }

  String? validateFuelOdometer(double odometerKm, {int? excludeId}) {
    final others = fuelEntries.where((e) => e.id != excludeId);
    if (others.isEmpty) return null;
    final maxOd = others.map((e) => e.odometerKm).reduce((a, b) => a > b ? a : b);
    if (odometerKm < maxOd) {
      return 'Odometer must be ≥ previous reading (${maxOd.toStringAsFixed(0)} km)';
    }
    return null;
  }

  Future<void> saveFuel(FuelEntry entry, {bool isNew = false}) async {
    final previousOdo = latestOdometer;
    if (isNew) {
      await _db.insertFuel(entry);
    } else {
      await _db.updateFuel(entry);
    }
    fuelEntries = await _db.getFuelEntries();
    await _notifications.notifyOdometerCrossings(
      reminders: reminders,
      previousOdometerKm: previousOdo,
      currentOdometerKm: latestOdometer,
    );
    notifyListeners();
  }

  Future<void> deleteFuel(int id) async {
    await _db.deleteFuel(id);
    fuelEntries = await _db.getFuelEntries();
    notifyListeners();
  }

  Future<void> saveRepair(RepairEntry entry, {bool isNew = false}) async {
    if (isNew) {
      await _db.insertRepair(entry);
    } else {
      await _db.updateRepair(entry);
    }
    repairs = await _db.getRepairs();
    notifyListeners();
  }

  Future<void> deleteRepair(int id) async {
    await _db.deleteRepair(id);
    repairs = await _db.getRepairs();
    notifyListeners();
  }

  Future<void> saveReminder(ReminderEntry entry) async {
    await _db.upsertReminder(entry);
    reminders = await _db.getReminders();
    await _notifications.syncReminders(reminders);
    notifyListeners();
  }

  FavoritePlace? favoriteByKind(PlaceKind kind) {
    for (final f in favorites) {
      if (f.kind == kind) return f;
    }
    return null;
  }

  Future<void> saveFavorite(FavoritePlace place, {bool isNew = false}) async {
    if (isNew) {
      await _db.insertFavorite(place);
    } else {
      await _db.updateFavorite(place);
    }
    favorites = await _db.getFavorites();
    notifyListeners();
  }

  Future<void> deleteFavorite(int id) async {
    await _db.deleteFavorite(id);
    favorites = await _db.getFavorites();
    notifyListeners();
  }

  /// Call after a destination is chosen and routing succeeds.
  Future<void> recordDestinationUse({
    required String name,
    required double latitude,
    required double longitude,
    int? favoriteId,
  }) async {
    await _db.upsertRecent(
      name: name,
      latitude: latitude,
      longitude: longitude,
    );
    if (favoriteId != null) {
      await _db.recordFavoriteVisit(favoriteId);
    } else {
      for (final f in favorites) {
        final dLat = (f.latitude - latitude).abs();
        final dLon = (f.longitude - longitude).abs();
        if (dLat < 0.0004 && dLon < 0.0004) {
          await _db.recordFavoriteVisit(f.id);
          break;
        }
      }
    }
    favorites = await _db.getFavorites();
    recentDestinations = await _db.getRecents();
    notifyListeners();
  }

  void setVoiceEnabled(bool enabled) {
    voice.enabled = enabled;
    notifyListeners();
  }

  void setVoiceVolume(double volume) {
    voice.volume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  void shiftDashboardMonth(int delta) {
    dashboardMonth = DateTime(dashboardMonth.year, dashboardMonth.month + delta);
    notifyListeners();
  }

  @override
  void dispose() {
    voice.dispose();
    navigation.disposeSession();
    super.dispose();
  }
}

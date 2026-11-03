enum ReminderKind { oilChange, insurance, vignette, visiteTechnique }

extension ReminderKindX on ReminderKind {
  String get storageKey => switch (this) {
        ReminderKind.oilChange => 'oil_change',
        ReminderKind.insurance => 'insurance',
        ReminderKind.vignette => 'vignette',
        ReminderKind.visiteTechnique => 'visite_technique',
      };

  String get labelFr => switch (this) {
        ReminderKind.oilChange => 'Vidange',
        ReminderKind.insurance => 'Assurance',
        ReminderKind.vignette => 'Vignette',
        ReminderKind.visiteTechnique => 'Visite technique',
      };

  static ReminderKind fromStorage(String value) => switch (value) {
        'oil_change' => ReminderKind.oilChange,
        'insurance' => ReminderKind.insurance,
        'vignette' => ReminderKind.vignette,
        'visite_technique' => ReminderKind.visiteTechnique,
        _ => throw ArgumentError('Unknown reminder kind: $value'),
      };
}

enum ReminderStatus { upcoming, due, overdue }

class FuelEntry {
  const FuelEntry({
    required this.id,
    required this.date,
    required this.liters,
    required this.totalPaidDh,
    required this.odometerKm,
    required this.isFullTank,
    this.station,
  });

  final int id;
  final DateTime date;
  final double liters;
  final double totalPaidDh;
  final double odometerKm;
  final bool isFullTank;
  final String? station;

  double get dhPerLiter => liters <= 0 ? double.nan : totalPaidDh / liters;

  FuelEntry copyWith({
    int? id,
    DateTime? date,
    double? liters,
    double? totalPaidDh,
    double? odometerKm,
    bool? isFullTank,
    String? station,
    bool clearStation = false,
  }) {
    return FuelEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      liters: liters ?? this.liters,
      totalPaidDh: totalPaidDh ?? this.totalPaidDh,
      odometerKm: odometerKm ?? this.odometerKm,
      isFullTank: isFullTank ?? this.isFullTank,
      station: clearStation ? null : (station ?? this.station),
    );
  }
}

class RepairEntry {
  const RepairEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.totalPriceDh,
  });

  final int id;
  final DateTime date;
  final String description;
  final double totalPriceDh;
}

class ReminderEntry {
  const ReminderEntry({
    required this.id,
    required this.kind,
    this.dueDate,
    this.dueOdometerKm,
    this.lastCompletedDate,
    this.lastCompletedOdometerKm,
    this.leadDays = 7,
    this.intervalMonths,
    this.intervalKm,
    this.notes,
  });

  final int id;
  final ReminderKind kind;
  final DateTime? dueDate;
  final double? dueOdometerKm;
  final DateTime? lastCompletedDate;
  final double? lastCompletedOdometerKm;
  final int leadDays;
  final int? intervalMonths;
  final double? intervalKm;
  final String? notes;

  ReminderStatus status({required DateTime today, double? latestOdometerKm}) {
    var overdue = false;
    var due = false;

    if (dueDate != null) {
      final dayOnly = DateTime(today.year, today.month, today.day);
      final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
      if (dayOnly.isAfter(dueDay)) {
        overdue = true;
      } else if (!dayOnly.isBefore(dueDay.subtract(Duration(days: leadDays)))) {
        due = true;
      }
    }

    if (dueOdometerKm != null && latestOdometerKm != null) {
      if (latestOdometerKm >= dueOdometerKm!) {
        overdue = true;
      } else if (latestOdometerKm >= dueOdometerKm! - 500) {
        due = true;
      }
    }

    if (overdue) return ReminderStatus.overdue;
    if (due) return ReminderStatus.due;
    return ReminderStatus.upcoming;
  }

  /// After marking renewed, set next due from configured intervals when present.
  ReminderEntry renew({
    required DateTime completedAt,
    double? completedOdometerKm,
  }) {
    DateTime? nextDue;
    double? nextOdo;

    final months = intervalMonths;
    if (months != null && months > 0) {
      nextDue = DateTime(
        completedAt.year,
        completedAt.month + months,
        completedAt.day,
      );
    }

    final km = intervalKm;
    if (km != null && km > 0 && completedOdometerKm != null) {
      nextOdo = completedOdometerKm + km;
    }

    return ReminderEntry(
      id: id,
      kind: kind,
      dueDate: nextDue,
      dueOdometerKm: nextOdo,
      lastCompletedDate: completedAt,
      lastCompletedOdometerKm: completedOdometerKm,
      leadDays: leadDays,
      intervalMonths: intervalMonths,
      intervalKm: intervalKm,
      notes: notes,
    );
  }

  ReminderEntry copyWith({
    DateTime? dueDate,
    double? dueOdometerKm,
    DateTime? lastCompletedDate,
    double? lastCompletedOdometerKm,
    int? leadDays,
    int? intervalMonths,
    double? intervalKm,
    String? notes,
    bool clearDueDate = false,
    bool clearDueOdometer = false,
    bool clearIntervalMonths = false,
    bool clearIntervalKm = false,
    bool clearNotes = false,
  }) {
    return ReminderEntry(
      id: id,
      kind: kind,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      dueOdometerKm:
          clearDueOdometer ? null : (dueOdometerKm ?? this.dueOdometerKm),
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      lastCompletedOdometerKm:
          lastCompletedOdometerKm ?? this.lastCompletedOdometerKm,
      leadDays: leadDays ?? this.leadDays,
      intervalMonths:
          clearIntervalMonths ? null : (intervalMonths ?? this.intervalMonths),
      intervalKm: clearIntervalKm ? null : (intervalKm ?? this.intervalKm),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

enum PlaceKind { home, work, saved }

extension PlaceKindX on PlaceKind {
  String get storageKey => switch (this) {
        PlaceKind.home => 'home',
        PlaceKind.work => 'work',
        PlaceKind.saved => 'saved',
      };

  String get label => switch (this) {
        PlaceKind.home => 'Home',
        PlaceKind.work => 'Work',
        PlaceKind.saved => 'Saved',
      };

  static PlaceKind fromStorage(String? value) => switch (value) {
        'home' => PlaceKind.home,
        'work' => PlaceKind.work,
        _ => PlaceKind.saved,
      };
}

class FavoritePlace {
  const FavoritePlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.kind = PlaceKind.saved,
    this.visitCount = 0,
    this.lastUsed,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final PlaceKind kind;
  final int visitCount;
  final DateTime? lastUsed;
}

class RecentDestination {
  const RecentDestination({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.lastUsed,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime lastUsed;
}

class RecentTransaction {
  const RecentTransaction({
    required this.date,
    required this.label,
    required this.amountDh,
    required this.isFuel,
  });

  final DateTime date;
  final String label;
  final double amountDh;
  final bool isFuel;
}

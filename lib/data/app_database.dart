import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'my_logan.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE fuel_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date_ms INTEGER NOT NULL,
  liters REAL NOT NULL,
  total_paid_dh REAL NOT NULL,
  odometer_km REAL NOT NULL,
  is_full_tank INTEGER NOT NULL,
  station TEXT
)''');
        await db.execute('''
CREATE TABLE repair_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date_ms INTEGER NOT NULL,
  description TEXT NOT NULL,
  total_price_dh REAL NOT NULL
)''');
        await db.execute('''
CREATE TABLE reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL UNIQUE,
  due_date_ms INTEGER,
  due_odometer_km REAL,
  last_completed_date_ms INTEGER,
  last_completed_odometer_km REAL,
  lead_days INTEGER NOT NULL DEFAULT 7,
  interval_months INTEGER,
  interval_km REAL,
  notes TEXT
)''');
        await db.execute('''
CREATE TABLE favorite_places (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL
)''');

        for (final kind in ReminderKind.values) {
          await db.insert('reminders', {
            'kind': kind.storageKey,
            'lead_days': 7,
          });
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE reminders ADD COLUMN interval_months INTEGER',
          );
          await db.execute(
            'ALTER TABLE reminders ADD COLUMN interval_km REAL',
          );
        }
      },
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }

  // --- Fuel ---

  Future<List<FuelEntry>> getFuelEntries() async {
    final db = await database;
    final rows = await db.query('fuel_entries', orderBy: 'date_ms DESC, id DESC');
    return rows.map(_fuelFromRow).toList();
  }

  Future<FuelEntry?> getLatestFuelEntry() async {
    final db = await database;
    final rows = await db.query(
      'fuel_entries',
      orderBy: 'odometer_km DESC, date_ms DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fuelFromRow(rows.first);
  }

  Future<int> insertFuel(FuelEntry entry) async {
    final db = await database;
    return db.insert('fuel_entries', _fuelToRow(entry, includeId: false));
  }

  Future<void> updateFuel(FuelEntry entry) async {
    final db = await database;
    await db.update(
      'fuel_entries',
      _fuelToRow(entry, includeId: false),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteFuel(int id) async {
    final db = await database;
    await db.delete('fuel_entries', where: 'id = ?', whereArgs: [id]);
  }

  // --- Repairs ---

  Future<List<RepairEntry>> getRepairs() async {
    final db = await database;
    final rows = await db.query('repair_entries', orderBy: 'date_ms DESC, id DESC');
    return rows.map(_repairFromRow).toList();
  }

  Future<int> insertRepair(RepairEntry entry) async {
    final db = await database;
    return db.insert('repair_entries', _repairToRow(entry, includeId: false));
  }

  Future<void> updateRepair(RepairEntry entry) async {
    final db = await database;
    await db.update(
      'repair_entries',
      _repairToRow(entry, includeId: false),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteRepair(int id) async {
    final db = await database;
    await db.delete('repair_entries', where: 'id = ?', whereArgs: [id]);
  }

  // --- Reminders ---

  Future<List<ReminderEntry>> getReminders() async {
    final db = await database;
    final rows = await db.query('reminders', orderBy: 'id ASC');
    return rows.map(_reminderFromRow).toList();
  }

  Future<void> upsertReminder(ReminderEntry entry) async {
    final db = await database;
    await db.update(
      'reminders',
      {
        'due_date_ms': entry.dueDate?.millisecondsSinceEpoch,
        'due_odometer_km': entry.dueOdometerKm,
        'last_completed_date_ms': entry.lastCompletedDate?.millisecondsSinceEpoch,
        'last_completed_odometer_km': entry.lastCompletedOdometerKm,
        'lead_days': entry.leadDays,
        'interval_months': entry.intervalMonths,
        'interval_km': entry.intervalKm,
        'notes': entry.notes,
      },
      where: 'kind = ?',
      whereArgs: [entry.kind.storageKey],
    );
  }

  // --- Favorites ---

  Future<List<FavoritePlace>> getFavorites() async {
    final db = await database;
    final rows = await db.query('favorite_places', orderBy: 'id ASC');
    return rows
        .map(
          (r) => FavoritePlace(
            id: r['id'] as int,
            name: r['name'] as String,
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<int> insertFavorite(FavoritePlace place) async {
    final db = await database;
    return db.insert('favorite_places', {
      'name': place.name,
      'latitude': place.latitude,
      'longitude': place.longitude,
    });
  }

  Future<void> updateFavorite(FavoritePlace place) async {
    final db = await database;
    await db.update(
      'favorite_places',
      {
        'name': place.name,
        'latitude': place.latitude,
        'longitude': place.longitude,
      },
      where: 'id = ?',
      whereArgs: [place.id],
    );
  }

  Future<void> deleteFavorite(int id) async {
    final db = await database;
    await db.delete('favorite_places', where: 'id = ?', whereArgs: [id]);
  }

  FuelEntry _fuelFromRow(Map<String, Object?> r) => FuelEntry(
        id: r['id'] as int,
        date: DateTime.fromMillisecondsSinceEpoch(r['date_ms'] as int),
        liters: (r['liters'] as num).toDouble(),
        totalPaidDh: (r['total_paid_dh'] as num).toDouble(),
        odometerKm: (r['odometer_km'] as num).toDouble(),
        isFullTank: (r['is_full_tank'] as int) == 1,
        station: r['station'] as String?,
      );

  Map<String, Object?> _fuelToRow(FuelEntry e, {required bool includeId}) => {
        if (includeId) 'id': e.id,
        'date_ms': e.date.millisecondsSinceEpoch,
        'liters': e.liters,
        'total_paid_dh': e.totalPaidDh,
        'odometer_km': e.odometerKm,
        'is_full_tank': e.isFullTank ? 1 : 0,
        'station': e.station,
      };

  RepairEntry _repairFromRow(Map<String, Object?> r) => RepairEntry(
        id: r['id'] as int,
        date: DateTime.fromMillisecondsSinceEpoch(r['date_ms'] as int),
        description: r['description'] as String,
        totalPriceDh: (r['total_price_dh'] as num).toDouble(),
      );

  Map<String, Object?> _repairToRow(RepairEntry e, {required bool includeId}) => {
        if (includeId) 'id': e.id,
        'date_ms': e.date.millisecondsSinceEpoch,
        'description': e.description,
        'total_price_dh': e.totalPriceDh,
      };

  ReminderEntry _reminderFromRow(Map<String, Object?> r) => ReminderEntry(
        id: r['id'] as int,
        kind: ReminderKindX.fromStorage(r['kind'] as String),
        dueDate: r['due_date_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['due_date_ms'] as int),
        dueOdometerKm: (r['due_odometer_km'] as num?)?.toDouble(),
        lastCompletedDate: r['last_completed_date_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['last_completed_date_ms'] as int),
        lastCompletedOdometerKm:
            (r['last_completed_odometer_km'] as num?)?.toDouble(),
        leadDays: r['lead_days'] as int? ?? 7,
        intervalMonths: r['interval_months'] as int?,
        intervalKm: (r['interval_km'] as num?)?.toDouble(),
        notes: r['notes'] as String?,
      );
}

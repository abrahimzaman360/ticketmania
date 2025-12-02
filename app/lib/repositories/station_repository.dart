import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import '../database/app_database.dart' as db;
import '../models/station.dart';
import '../main.dart';
import '../providers/database_provider.dart';

/// Repository for managing stations with offline-first support
class StationRepository {
  final db.AppDatabase _db;
  final bool isOnline;

  StationRepository(this._db, this.isOnline);

  /// Get all stations
  Future<List<Station>> getStations() async {
    // Get from local database first
    final localStations = await (_db.select(_db.stations)
          ..where((s) => s.isActive.equals(true))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .get();

    // Convert to Station models
    final stations = localStations.map((row) => _stationFromRow(row)).toList();

    // If online, sync with server
    if (isOnline) {
      try {
        await _syncStations();
        // Return fresh data after sync
        final updatedStations = await (_db.select(_db.stations)
              ..where((s) => s.isActive.equals(true))
              ..orderBy([(s) => OrderingTerm.asc(s.name)]))
            .get();
        return updatedStations.map((row) => _stationFromRow(row)).toList();
      } catch (e) {
        // If sync fails, return local data
        return stations;
      }
    }

    return stations;
  }

  /// Sync stations with server
  Future<void> _syncStations() async {
    try {
      final response = await supabase
          .from('stations')
          .select()
          .eq('is_active', true)
          .order('name');

      final now = DateTime.now();

      // Update local database
      for (final json in response) {
        final station = Station.fromJson(json);
        await _db.into(_db.stations).insertOnConflictUpdate(_stationToRow(station, now));
      }
    } catch (e) {
      throw Exception('Failed to sync stations: $e');
    }
  }

  Station _stationFromRow(db.Station row) {
    return Station(
      id: row.id,
      name: row.name,
      code: row.code,
      latitude: row.latitude,
      longitude: row.longitude,
      city: row.city,
      country: row.country,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  db.StationsCompanion _stationToRow(Station station, DateTime lastSyncedAt) {
    return db.StationsCompanion.insert(
      id: station.id,
      name: station.name,
      code: station.code,
      latitude: station.latitude,
      longitude: station.longitude,
      city: Value(station.city),
      country: station.country,
      isActive: station.isActive,
      createdAt: station.createdAt,
      lastSyncedAt: Value(lastSyncedAt),
    );
  }
}

/// Provider for station repository
final stationRepositoryProvider = Provider.family<StationRepository, bool>((ref, isOnline) {
  final db = ref.watch(databaseProvider);
  return StationRepository(db, isOnline);
});


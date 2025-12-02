import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import '../database/app_database.dart' as db;
import '../models/ticket_type.dart';
import '../main.dart';
import '../providers/database_provider.dart';

/// Repository for managing ticket types with offline-first support
class TicketTypeRepository {
  final db.AppDatabase _db;
  final bool isOnline;

  TicketTypeRepository(this._db, this.isOnline);

  /// Get all ticket types
  Future<List<TicketType>> getTicketTypes() async {
    // Get from local database first
    final localTypes = await (_db.select(_db.ticketTypes)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();

    // Convert to TicketType models
    final ticketTypes = localTypes.map((row) => _ticketTypeFromRow(row)).toList();

    // If online, sync with server
    if (isOnline) {
      try {
        await _syncTicketTypes();
        // Return fresh data after sync
        final updatedTypes = await (_db.select(_db.ticketTypes)
              ..where((t) => t.isActive.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
        return updatedTypes.map((row) => _ticketTypeFromRow(row)).toList();
      } catch (e) {
        // If sync fails, return local data
        return ticketTypes;
      }
    }

    return ticketTypes;
  }

  /// Sync ticket types with server
  Future<void> _syncTicketTypes() async {
    try {
      final response = await supabase
          .from('ticket_types')
          .select()
          .eq('is_active', true)
          .order('name');

      final now = DateTime.now();

      // Update local database
      for (final json in response) {
        final ticketType = TicketType.fromJson(json);
        await _db.into(_db.ticketTypes).insertOnConflictUpdate(_ticketTypeToRow(ticketType, now));
      }
    } catch (e) {
      throw Exception('Failed to sync ticket types: $e');
    }
  }

  TicketType _ticketTypeFromRow(db.TicketType row) {
    return TicketType(
      id: row.id,
      name: row.name,
      description: row.description,
      price: row.price,
      durationMinutes: row.durationMinutes,
      validityType: ValidityType.fromString(row.validityType),
      category: row.category,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  db.TicketTypesCompanion _ticketTypeToRow(TicketType ticketType, DateTime lastSyncedAt) {
    return db.TicketTypesCompanion.insert(
      id: ticketType.id,
      name: ticketType.name,
      description: Value(ticketType.description),
      price: ticketType.price,
      durationMinutes: Value(ticketType.durationMinutes),
      validityType: ticketType.validityType.value,
      category: ticketType.category,
      isActive: ticketType.isActive,
      createdAt: ticketType.createdAt,
      lastSyncedAt: Value(lastSyncedAt),
    );
  }
}

/// Provider for ticket type repository
final ticketTypeRepositoryProvider = Provider.family<TicketTypeRepository, bool>((ref, isOnline) {
  final db = ref.watch(databaseProvider);
  return TicketTypeRepository(db, isOnline);
});


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import '../database/app_database.dart' as db;
import '../main.dart';
import '../providers/database_provider.dart';
import 'dart:convert';

/// Service for syncing queued operations when online
class SyncService {
  final db.AppDatabase _db;

  SyncService(this._db);

  /// Process all queued sync operations
  Future<void> syncQueuedOperations() async {
    final queue = await (_db.select(
      _db.syncQueue,
    )..orderBy([(q) => OrderingTerm.asc(q.createdAt)])).get();

    for (final item in queue) {
      try {
        await _processSyncItem(item);
        // Remove from queue on success
        await (_db.delete(
          _db.syncQueue,
        )..where((q) => q.id.equals(item.id))).go();
      } catch (e) {
        // Increment retry count
        await (_db.update(
          _db.syncQueue,
        )..where((q) => q.id.equals(item.id))).write(
          db.SyncQueueCompanion(retryCount: Value(item.retryCount + 1)),
        );

        // If retry count exceeds threshold, remove from queue
        if (item.retryCount >= 5) {
          await (_db.delete(
            _db.syncQueue,
          )..where((q) => q.id.equals(item.id))).go();
        }
      }
    }
  }

  Future<void> _processSyncItem(db.SyncQueueData item) async {
    final data = jsonDecode(item.data) as Map<String, dynamic>;

    switch (item.operation) {
      case 'insert':
        await supabase.from(item.targetTable).insert(data);
        break;
      case 'update':
        await supabase
            .from(item.targetTable)
            .update(data)
            .eq('id', item.recordId);
        break;
      case 'delete':
        await supabase.from(item.targetTable).delete().eq('id', item.recordId);
        break;
    }
  }
}

/// Provider for sync service
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

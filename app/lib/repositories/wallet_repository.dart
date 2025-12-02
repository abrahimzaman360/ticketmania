import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart' as db;
import '../models/wallet.dart' as models;
import '../main.dart';
import '../providers/database_provider.dart';

/// Repository for managing wallet with offline-first support
class WalletRepository {
  final db.AppDatabase _db;
  final bool isOnline;

  WalletRepository(this._db, this.isOnline);

  /// Get wallet for the current user
  /// Returns cached wallet if offline, syncs and returns if online
  Future<models.Wallet?> getWallet() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    // Always get from local database first (offline-first)
    final localWallet = await (_db.select(_db.wallets)
          ..where((w) => w.userId.equals(userId))
          ..limit(1))
        .getSingleOrNull();

    // If online, sync with server in background
    if (isOnline) {
      try {
        await _syncWallet(userId);
        // After sync, get updated data from local database
        final updatedWallet = await (_db.select(_db.wallets)
              ..where((w) => w.userId.equals(userId))
              ..limit(1))
            .getSingleOrNull();
        
        if (updatedWallet != null) {
          return _walletFromRow(updatedWallet);
        }
      } catch (e) {
        debugPrint('Error syncing wallet: $e');
        // Continue with local data if sync fails
      }
    }

    // Return local wallet (from cache) if available
    if (localWallet != null) {
      return _walletFromRow(localWallet);
    }

    return null;
  }

  /// Get wallet balance (for BLE validation - must work offline)
  Future<double> getWalletBalance() async {
    final wallet = await getWallet();
    return wallet?.balance ?? 0.0;
  }

  /// Sync wallet from server
  Future<void> _syncWallet(String userId) async {
    try {
      final response = await supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final wallet = models.Wallet.fromJson(response);
        
        // Update local database
        await _db.into(_db.wallets).insertOnConflictUpdate(
          _walletToRow(wallet, lastSyncedAt: DateTime.now()),
        );
      }
    } catch (e) {
      debugPrint('Error syncing wallet: $e');
      rethrow;
    }
  }

  /// Convert database row to Wallet model
  models.Wallet _walletFromRow(db.Wallet row) {
    return models.Wallet(
      id: row.id,
      userId: row.userId,
      balance: row.balance,
      currency: row.currency,
      autoTopupEnabled: row.autoTopupEnabled,
      autoTopupLimit: row.autoTopupLimit,
      autoTopupAmount: row.autoTopupAmount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Convert Wallet model to database row
  db.WalletsCompanion _walletToRow(models.Wallet wallet, {DateTime? lastSyncedAt}) {
    return db.WalletsCompanion.insert(
      id: wallet.id,
      userId: wallet.userId,
      balance: wallet.balance,
      currency: wallet.currency,
      autoTopupEnabled: wallet.autoTopupEnabled,
      autoTopupLimit: wallet.autoTopupLimit,
      autoTopupAmount: wallet.autoTopupAmount,
      createdAt: wallet.createdAt,
      updatedAt: wallet.updatedAt,
      lastSyncedAt: Value(lastSyncedAt),
    );
  }
}

/// Provider for wallet repository
final walletRepositoryProvider = Provider.family<WalletRepository, bool>((ref, isOnline) {
  final db = ref.watch(databaseProvider);
  return WalletRepository(db, isOnline);
});


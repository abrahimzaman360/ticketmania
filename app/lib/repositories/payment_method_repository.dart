import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart' as db;
import '../models/payment_method.dart' as models;
import '../main.dart';
import '../providers/database_provider.dart';
import 'dart:convert';

const _uuid = Uuid();

/// Repository for managing payment methods with offline-first support
class PaymentMethodRepository {
  final db.AppDatabase _db;
  final bool isOnline;

  PaymentMethodRepository(this._db, this.isOnline);

  /// Get all payment methods for the current user
  Future<List<models.PaymentMethod>> getPaymentMethods() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('PaymentMethodRepository: No user ID');
      return [];
    }

    // If online, sync with server first
    if (isOnline) {
      try {
        await _syncPaymentMethods(userId);
      } catch (e) {
        debugPrint('Error syncing payment methods: $e');
        // Continue with local data if sync fails
      }
    }

    // Get from local database
    final localMethods =
        await (_db.select(_db.paymentMethods)
              ..where((p) => p.userId.equals(userId))
              ..orderBy([
                (p) => OrderingTerm.desc(p.isDefault),
                (p) => OrderingTerm.desc(p.createdAt),
              ]))
            .get();

    debugPrint(
      'PaymentMethodRepository: Found ${localMethods.length} payment methods in local DB',
    );

    // Convert to PaymentMethod models
    final methods = localMethods
        .map((row) => _paymentMethodFromRow(row))
        .toList();
    return methods;
  }

  /// Add a new payment method
  Future<models.PaymentMethod> addPaymentMethod({
    required models.PaymentMethodType type,
    String? cardNumber,
    String? cardHolderName,
    String? expiryMonth,
    String? expiryYear,
    String? brand,
    bool setAsDefault = false,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final paymentMethodId = _uuid.v4();
    final now = DateTime.now();

    // Sanitize card holder name
    String? sanitizedCardHolderName;
    if (cardHolderName != null) {
      sanitizedCardHolderName = cardHolderName.trim().replaceAll(
        RegExp(
          r'[<>"\'
          ']',
        ),
        '',
      );
    }

    final paymentMethod = models.PaymentMethod(
      id: paymentMethodId,
      userId: userId,
      type: type,
      cardNumber: cardNumber?.length == 4 ? cardNumber : null,
      cardHolderName: sanitizedCardHolderName,
      expiryMonth: expiryMonth?.trim(),
      expiryYear: expiryYear?.trim(),
      brand: brand?.trim(),
      isDefault: setAsDefault,
      createdAt: now,
      updatedAt: now,
    );

    // Save to local database
    await _db
        .into(_db.paymentMethods)
        .insert(_paymentMethodToRow(paymentMethod, isSynced: !isOnline));

    // If setting as default, unset other defaults
    if (setAsDefault) {
      // First, get all payment methods for this user
      final userMethods = await (_db.select(
        _db.paymentMethods,
      )..where((p) => p.userId.equals(userId))).get();

      // Update all except the new one
      for (final method in userMethods) {
        if (method.id != paymentMethodId) {
          await (_db.update(
            _db.paymentMethods,
          )..where((p) => p.id.equals(method.id))).write(
            db.PaymentMethodsCompanion(
              isDefault: const Value(false),
              updatedAt: Value(now),
            ),
          );
        }
      }
    }

    // If online, sync immediately
    if (isOnline) {
      try {
        await _syncCreatePaymentMethod(paymentMethod);
        // Update sync status
        await (_db.update(
          _db.paymentMethods,
        )..where((p) => p.id.equals(paymentMethodId))).write(
          db.PaymentMethodsCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(now),
          ),
        );
      } catch (e) {
        // Queue for later sync
        await _queueSync(
          'payment_methods',
          'insert',
          paymentMethodId,
          paymentMethod.toJson(),
        );
      }
    } else {
      // Queue for later sync
      await _queueSync(
        'payment_methods',
        'insert',
        paymentMethodId,
        paymentMethod.toJson(),
      );
    }

    return paymentMethod;
  }

  /// Update a payment method
  Future<models.PaymentMethod> updatePaymentMethod({
    required String id,
    String? cardHolderName,
    String? expiryMonth,
    String? expiryYear,
    bool? setAsDefault,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final now = DateTime.now();

    // If setting as default, unset other defaults
    if (setAsDefault == true) {
      // First, get all payment methods for this user
      final userMethods = await (_db.select(
        _db.paymentMethods,
      )..where((p) => p.userId.equals(userId))).get();

      // Update all except the one being updated
      for (final method in userMethods) {
        if (method.id != id) {
          await (_db.update(
            _db.paymentMethods,
          )..where((p) => p.id.equals(method.id))).write(
            db.PaymentMethodsCompanion(
              isDefault: const Value(false),
              updatedAt: Value(now),
            ),
          );
        }
      }
    }

    // Update local database
    final updateCompanion = db.PaymentMethodsCompanion(
      updatedAt: Value(now),
      isSynced: const Value(false),
      cardHolderName: cardHolderName != null
          ? Value(
              cardHolderName.trim().replaceAll(
                RegExp(
                  r'[<>"\'
                  ']',
                ),
                '',
              ),
            )
          : const Value.absent(),
      expiryMonth: expiryMonth != null
          ? Value(expiryMonth.trim())
          : const Value.absent(),
      expiryYear: expiryYear != null
          ? Value(expiryYear.trim())
          : const Value.absent(),
      isDefault: setAsDefault != null
          ? Value(setAsDefault)
          : const Value.absent(),
    );

    // Verify user owns this payment method before updating
    final existing = await (_db.select(
      _db.paymentMethods,
    )..where((p) => p.id.equals(id))).getSingleOrNull();

    if (existing == null || existing.userId != userId) {
      throw Exception('Payment method not found or access denied');
    }

    await (_db.update(
      _db.paymentMethods,
    )..where((p) => p.id.equals(id))).write(updateCompanion);

    // If online, sync immediately
    if (isOnline) {
      try {
        await _syncUpdatePaymentMethod(id, {
          if (cardHolderName != null) 'card_holder_name': cardHolderName.trim(),
          if (expiryMonth != null) 'expiry_month': expiryMonth.trim(),
          if (expiryYear != null) 'expiry_year': expiryYear.trim(),
          if (setAsDefault != null) 'is_default': setAsDefault,
          'updated_at': now.toUtc().toIso8601String(),
        });
        // Update sync status
        await (_db.update(
          _db.paymentMethods,
        )..where((p) => p.id.equals(id))).write(
          db.PaymentMethodsCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(now),
          ),
        );
      } catch (e) {
        // Queue for later sync
        await _queueSync('payment_methods', 'update', id, {
          if (cardHolderName != null) 'card_holder_name': cardHolderName.trim(),
          if (expiryMonth != null) 'expiry_month': expiryMonth.trim(),
          if (expiryYear != null) 'expiry_year': expiryYear.trim(),
          if (setAsDefault != null) 'is_default': setAsDefault,
        });
      }
    } else {
      // Queue for later sync
      await _queueSync('payment_methods', 'update', id, {
        if (cardHolderName != null) 'card_holder_name': cardHolderName.trim(),
        if (expiryMonth != null) 'expiry_month': expiryMonth.trim(),
        if (expiryYear != null) 'expiry_year': expiryYear.trim(),
        if (setAsDefault != null) 'is_default': setAsDefault,
      });
    }

    // Return updated payment method
    final updated = await (_db.select(
      _db.paymentMethods,
    )..where((p) => p.id.equals(id))).getSingle();
    return _paymentMethodFromRow(updated);
  }

  /// Delete a payment method
  Future<void> deletePaymentMethod(String id) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Verify user owns this payment method before deleting
    final existing = await (_db.select(
      _db.paymentMethods,
    )..where((p) => p.id.equals(id))).getSingleOrNull();

    if (existing == null || existing.userId != userId) {
      throw Exception('Payment method not found or access denied');
    }

    // Delete from local database
    await (_db.delete(_db.paymentMethods)..where((p) => p.id.equals(id))).go();

    // If online, sync immediately
    if (isOnline) {
      try {
        await _syncDeletePaymentMethod(id);
      } catch (e) {
        // Queue for later sync
        await _queueSync('payment_methods', 'delete', id, {});
      }
    } else {
      // Queue for later sync
      await _queueSync('payment_methods', 'delete', id, {});
    }
  }

  /// Set a payment method as default
  Future<void> setDefaultPaymentMethod(String id) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final now = DateTime.now();

    // Unset all defaults in local database
    await (_db.update(
      _db.paymentMethods,
    )..where((p) => p.userId.equals(userId))).write(
      db.PaymentMethodsCompanion(
        isDefault: const Value(false),
        updatedAt: Value(now),
        isSynced: const Value(false),
      ),
    );

    // Verify user owns this payment method before setting as default
    final existing = await (_db.select(
      _db.paymentMethods,
    )..where((p) => p.id.equals(id))).getSingleOrNull();

    if (existing == null || existing.userId != userId) {
      throw Exception('Payment method not found or access denied');
    }

    // Set new default
    await (_db.update(_db.paymentMethods)..where((p) => p.id.equals(id))).write(
      db.PaymentMethodsCompanion(
        isDefault: const Value(true),
        updatedAt: Value(now),
        isSynced: Value(!isOnline),
      ),
    );

    // If online, sync immediately
    if (isOnline) {
      try {
        await supabase
            .from('payment_methods')
            .update({'is_default': false})
            .eq('user_id', userId);

        await supabase
            .from('payment_methods')
            .update({
              'is_default': true,
              'updated_at': now.toUtc().toIso8601String(),
            })
            .eq('id', id)
            .eq('user_id', userId);

        // Update sync status
        await (_db.update(
          _db.paymentMethods,
        )..where((p) => p.userId.equals(userId))).write(
          db.PaymentMethodsCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(now),
          ),
        );
      } catch (e) {
        // Queue for later sync
        await _queueSync('payment_methods', 'update', id, {'is_default': true});
      }
    } else {
      // Queue for later sync
      await _queueSync('payment_methods', 'update', id, {'is_default': true});
    }
  }

  /// Sync payment methods with server
  Future<void> _syncPaymentMethods(String userId) async {
    try {
      // Fetch from server
      final response = await supabase
          .from('payment_methods')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      final now = DateTime.now();

      // Update local database
      for (final json in response) {
        final paymentMethod = models.PaymentMethod.fromJson(json);
        await _db
            .into(_db.paymentMethods)
            .insertOnConflictUpdate(
              _paymentMethodToRow(
                paymentMethod,
                isSynced: true,
                lastSyncedAt: now,
              ),
            );
      }
    } catch (e) {
      throw Exception('Failed to sync payment methods: $e');
    }
  }

  /// Sync create payment method to server
  Future<void> _syncCreatePaymentMethod(
    models.PaymentMethod paymentMethod,
  ) async {
    final data = paymentMethod.toJson();
    await supabase.from('payment_methods').insert(data);
  }

  /// Sync update payment method to server
  Future<void> _syncUpdatePaymentMethod(
    String id,
    Map<String, dynamic> data,
  ) async {
    await supabase.from('payment_methods').update(data).eq('id', id);
  }

  /// Sync delete payment method to server
  Future<void> _syncDeletePaymentMethod(String id) async {
    await supabase.from('payment_methods').delete().eq('id', id);
  }

  /// Queue operation for later sync
  Future<void> _queueSync(
    String tableName,
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    await _db
        .into(_db.syncQueue)
        .insert(
          db.SyncQueueCompanion.insert(
            targetTable: tableName,
            operation: operation,
            recordId: recordId,
            data: jsonEncode(data),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Convert database row to PaymentMethod model
  models.PaymentMethod _paymentMethodFromRow(db.PaymentMethod row) {
    return models.PaymentMethod(
      id: row.id,
      userId: row.userId,
      type: models.PaymentMethodType.fromString(row.type),
      cardNumber: row.cardNumber,
      cardHolderName: row.cardHolderName,
      expiryMonth: row.expiryMonth,
      expiryYear: row.expiryYear,
      brand: row.brand,
      isDefault: row.isDefault,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Convert PaymentMethod model to database row
  db.PaymentMethodsCompanion _paymentMethodToRow(
    models.PaymentMethod paymentMethod, {
    bool isSynced = false,
    DateTime? lastSyncedAt,
  }) {
    return db.PaymentMethodsCompanion.insert(
      id: paymentMethod.id,
      userId: paymentMethod.userId,
      type: paymentMethod.type.value,
      cardNumber: Value(paymentMethod.cardNumber),
      cardHolderName: Value(paymentMethod.cardHolderName),
      expiryMonth: Value(paymentMethod.expiryMonth),
      expiryYear: Value(paymentMethod.expiryYear),
      brand: Value(paymentMethod.brand),
      isDefault: Value(paymentMethod.isDefault),
      createdAt: paymentMethod.createdAt,
      updatedAt: paymentMethod.updatedAt,
      isSynced: Value(isSynced),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }
}

/// Provider for payment method repository
final paymentMethodRepositoryProvider =
    Provider.family<PaymentMethodRepository, bool>((ref, isOnline) {
      final db = ref.watch(databaseProvider);
      return PaymentMethodRepository(db, isOnline);
    });

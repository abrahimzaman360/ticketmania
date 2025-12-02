import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart' as db;
import '../models/booking.dart' as models;
import '../main.dart';
import '../providers/database_provider.dart';
import 'dart:convert';

const _uuid = Uuid();

/// Repository for managing bookings with offline-first support
class BookingRepository {
  final db.AppDatabase _db;
  final bool isOnline;

  BookingRepository(this._db, this.isOnline);

  /// Get all bookings for the current user
  Future<List<models.Booking>> getBookings() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Verify user exists in database if online
    if (isOnline) {
      try {
        final profile = await supabase
            .from('profiles')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
        if (profile == null) {
          debugPrint('User not found in database, logging out...');
          await supabase.auth.signOut();
          return [];
        }
      } catch (e) {
        debugPrint('Error verifying user in getBookings: $e');
        // Continue if verification fails (might be network issue)
      }
    }

    // Always get from local database first (offline-first)
    final localBookings = await (_db.select(_db.bookings)
          ..where((b) => b.userId.equals(userId))
          ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
        .get();

    // If online, sync with server in background
    if (isOnline) {
      try {
        // Sync bookings from server (this will update local DB)
        await _syncBookings(userId);
        // After sync, get updated data from local database
        final updatedBookings = await (_db.select(_db.bookings)
              ..where((b) => b.userId.equals(userId))
              ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
            .get();
        
        // Convert to Booking models with related data
        final bookings = await Future.wait(
          updatedBookings.map((row) => _bookingFromRow(row)),
        );
        return bookings;
      } catch (e) {
        debugPrint('Error syncing bookings: $e');
        // Continue with local data if sync fails
      }
    }

    // Convert to Booking models with related data (from local DB)
    final bookings = await Future.wait(
      localBookings.map((row) => _bookingFromRow(row)),
    );

    return bookings;
  }

  /// Get active bookings
  Future<List<models.Booking>> getActiveBookings() async {
    final allBookings = await getBookings();
    final activeBookings = allBookings.where((b) {
      // Active bookings are those with status 'active', 'confirmed', or 'pending' that are still valid
      final isActiveStatus = b.status == models.BookingStatus.active || 
                            b.status == models.BookingStatus.confirmed ||
                            b.status == models.BookingStatus.pending;
      // Check if ticket is still valid (not expired)
      final isValid = b.validUntil == null || b.validUntil!.isAfter(DateTime.now());
      // Also check if it hasn't been used or cancelled
      final notUsedOrCancelled = b.status != models.BookingStatus.used && 
                                 b.status != models.BookingStatus.cancelled &&
                                 b.status != models.BookingStatus.expired;
      return isActiveStatus && isValid && notUsedOrCancelled;
    }).toList();
    
    debugPrint('Found ${allBookings.length} total bookings, ${activeBookings.length} active bookings');
    return activeBookings;
  }

  /// Create a new booking
  Future<models.Booking> createBooking({
    required String ticketTypeId,
    String? fromStationId,
    String? toStationId,
    required int quantity,
    required double totalPrice,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final bookingId = _uuid.v4();
    final now = DateTime.now();

    final booking = models.Booking(
      id: bookingId,
      userId: userId,
      ticketTypeId: ticketTypeId,
      fromStationId: fromStationId,
      toStationId: toStationId,
      quantity: quantity,
      totalPrice: totalPrice,
      status: models.BookingStatus.confirmed,
      createdAt: now,
      updatedAt: now,
    );

    // Save to local database
    await _db.into(_db.bookings).insert(_bookingToRow(booking, isSynced: !isOnline));

    // If online, sync immediately
    if (isOnline) {
      try {
        await _syncCreateBooking(booking);
        // Update sync status
        await (_db.update(_db.bookings)..where((b) => b.id.equals(bookingId)))
            .write(db.BookingsCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(now),
        ));
      } catch (e) {
        // Queue for later sync
        await _queueSync('bookings', 'insert', bookingId, booking.toJson());
      }
    } else {
      // Queue for later sync
      await _queueSync('bookings', 'insert', bookingId, booking.toJson());
    }

    return booking;
  }

  /// Validate a ticket
  Future<void> validateTicket(String bookingId, {String? validationType}) async {
    final now = DateTime.now();
    
    // Update local database
    await (_db.update(_db.bookings)..where((b) => b.id.equals(bookingId)))
        .write(db.BookingsCompanion(
      status: Value(models.BookingStatus.used.value),
      validatedAt: Value(now),
      updatedAt: Value(now),
      isSynced: const Value(false),
    ));

    // If online, sync immediately
    if (isOnline) {
      try {
        await supabase
            .from('bookings')
            .update({
              'status': models.BookingStatus.used.value,
              'validated_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('id', bookingId);

        await (_db.update(_db.bookings)..where((b) => b.id.equals(bookingId)))
            .write(db.BookingsCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(now),
        ));
      } catch (e) {
        await _queueSync('bookings', 'update', bookingId, {
          'status': models.BookingStatus.used.value,
          'validated_at': now.toIso8601String(),
        });
      }
    } else {
      await _queueSync('bookings', 'update', bookingId, {
        'status': models.BookingStatus.used.value,
        'validated_at': now.toIso8601String(),
      });
    }
  }

  /// Sync bookings with server
  Future<void> _syncBookings(String userId) async {
    try {
      // First, ensure ticket types and stations are synced
      // This is needed so we can look up related data from local DB
      try {
        await _syncTicketTypesAndStations();
      } catch (e) {
        debugPrint('Warning: Failed to sync ticket types/stations: $e');
        // Continue with booking sync even if this fails
      }

      // Fetch from server with related data
      final response = await supabase
          .from('bookings')
          .select('''
            *,
            ticket_types:ticket_types(name),
            from_station:stations!bookings_from_station_id_fkey(name),
            to_station:stations!bookings_to_station_id_fkey(name)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final now = DateTime.now();
      final serverBookingIds = <String>{};

      // Update local database with server data
      for (final json in response) {
        // Extract nested data
        final ticketTypeName = (json['ticket_types'] as Map<String, dynamic>?)?['name'] as String?;
        final fromStationName = (json['from_station'] as Map<String, dynamic>?)?['name'] as String?;
        final toStationName = (json['to_station'] as Map<String, dynamic>?)?['name'] as String?;

        // Create booking with related data
        final bookingJson = Map<String, dynamic>.from(json);
        bookingJson['ticket_type_name'] = ticketTypeName;
        bookingJson['from_station_name'] = fromStationName;
        bookingJson['to_station_name'] = toStationName;

        final booking = models.Booking.fromJson(bookingJson);
        serverBookingIds.add(booking.id);
        
        await _db.into(_db.bookings).insertOnConflictUpdate(
          _bookingToRow(booking, isSynced: true, lastSyncedAt: now),
        );
      }

      // Remove local bookings that don't exist on server (were deleted)
      // Only delete bookings that were previously synced (exist on server)
      // Don't delete unsynced local bookings (they might be pending sync)
      final localBookings = await (_db.select(_db.bookings)
            ..where((b) => b.userId.equals(userId)))
          .get();
      
      for (final localBooking in localBookings) {
        if (localBooking.isSynced && !serverBookingIds.contains(localBooking.id)) {
          debugPrint('Removing deleted booking from local DB: ${localBooking.id}');
          await (_db.delete(_db.bookings)..where((b) => b.id.equals(localBooking.id))).go();
        }
      }
    } catch (e) {
      debugPrint('Error syncing bookings: $e');
      throw Exception('Failed to sync bookings: $e');
    }
  }

  /// Sync ticket types and stations from server
  Future<void> _syncTicketTypesAndStations() async {
    try {
      // Sync ticket types
      final ticketTypesResponse = await supabase
          .from('ticket_types')
          .select()
          .eq('is_active', true)
          .order('name');

      final now = DateTime.now();
      for (final json in ticketTypesResponse) {
        // We need to convert to TicketType model, but we'll just store the raw data
        // The ticket type repository will handle the conversion
        // For now, we'll just ensure the data exists in the local DB
        await _db.into(_db.ticketTypes).insertOnConflictUpdate(
          db.TicketTypesCompanion.insert(
            id: json['id'] as String,
            name: json['name'] as String,
            description: Value(json['description'] as String?),
            price: (json['price'] as num).toDouble(),
            durationMinutes: Value(json['duration_minutes'] as int?),
            validityType: json['validity_type'] as String,
            category: json['category'] as String? ?? 'general',
            isActive: json['is_active'] as bool? ?? true,
            createdAt: DateTime.parse(json['created_at'] as String),
            lastSyncedAt: Value(now),
          ),
        );
      }

      // Sync stations
      final stationsResponse = await supabase
          .from('stations')
          .select()
          .eq('is_active', true)
          .order('name');

      for (final json in stationsResponse) {
        await _db.into(_db.stations).insertOnConflictUpdate(
          db.StationsCompanion.insert(
            id: json['id'] as String,
            name: json['name'] as String,
            code: json['code'] as String,
            latitude: (json['latitude'] as num).toDouble(),
            longitude: (json['longitude'] as num).toDouble(),
            city: Value(json['city'] as String?),
            country: json['country'] as String,
            isActive: json['is_active'] as bool? ?? true,
            createdAt: DateTime.parse(json['created_at'] as String),
            lastSyncedAt: Value(now),
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to sync ticket types and stations: $e');
    }
  }

  /// Sync create booking to server
  Future<void> _syncCreateBooking(models.Booking booking) async {
    await supabase.from('bookings').insert(booking.toJson());
  }

  /// Queue operation for later sync
  Future<void> _queueSync(String tableName, String operation, String recordId, Map<String, dynamic> data) async {
    await _db.into(_db.syncQueue).insert(db.SyncQueueCompanion.insert(
      targetTable: tableName,
      operation: operation,
      recordId: recordId,
      data: jsonEncode(data),
      createdAt: DateTime.now(),
    ));
  }

  /// Convert database row to Booking model with related data
  Future<models.Booking> _bookingFromRow(db.Booking row) async {
    // Load related data from local database
    String? ticketTypeName;
    String? fromStationName;
    String? toStationName;

    try {
      // Get ticket type name
      final ticketType = await (_db.select(_db.ticketTypes)
            ..where((t) => t.id.equals(row.ticketTypeId))
            ..limit(1))
          .getSingleOrNull();
      ticketTypeName = ticketType?.name;

      // Get from station name
      if (row.fromStationId != null) {
        final fromStation = await (_db.select(_db.stations)
              ..where((s) => s.id.equals(row.fromStationId!))
              ..limit(1))
            .getSingleOrNull();
        fromStationName = fromStation?.name;
      }

      // Get to station name
      if (row.toStationId != null) {
        final toStation = await (_db.select(_db.stations)
              ..where((s) => s.id.equals(row.toStationId!))
              ..limit(1))
            .getSingleOrNull();
        toStationName = toStation?.name;
      }
    } catch (e) {
      debugPrint('Error loading related data for booking ${row.id}: $e');
      // Continue without related data if there's an error
    }

    return models.Booking(
      id: row.id,
      userId: row.userId,
      ticketTypeId: row.ticketTypeId,
      fromStationId: row.fromStationId,
      toStationId: row.toStationId,
      quantity: row.quantity,
      totalPrice: row.totalPrice,
      status: models.BookingStatus.fromString(row.status),
      qrCode: row.qrCode,
      rfidToken: row.rfidToken,
      validFrom: row.validFrom,
      validUntil: row.validUntil,
      validatedAt: row.validatedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      ticketTypeName: ticketTypeName,
      fromStationName: fromStationName,
      toStationName: toStationName,
    );
  }

  /// Convert Booking model to database row
  db.BookingsCompanion _bookingToRow(models.Booking booking, {bool isSynced = false, DateTime? lastSyncedAt}) {
    return db.BookingsCompanion.insert(
      id: booking.id,
      userId: booking.userId,
      ticketTypeId: booking.ticketTypeId,
      fromStationId: Value(booking.fromStationId),
      toStationId: Value(booking.toStationId),
      quantity: booking.quantity,
      totalPrice: booking.totalPrice,
      status: booking.status.value,
      qrCode: Value(booking.qrCode),
      rfidToken: Value(booking.rfidToken),
      validFrom: Value(booking.validFrom),
      validUntil: Value(booking.validUntil),
      validatedAt: Value(booking.validatedAt),
      createdAt: booking.createdAt,
      updatedAt: booking.updatedAt,
      isSynced: Value(isSynced),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }
}

/// Provider for booking repository
final bookingRepositoryProvider = Provider.family<BookingRepository, bool>((ref, isOnline) {
  final db = ref.watch(databaseProvider);
  return BookingRepository(db, isOnline);
});


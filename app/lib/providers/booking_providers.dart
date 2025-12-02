import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/booking_repository.dart';
import '../providers/connectivity_provider.dart';
import '../models/booking.dart' as models;

/// Provider for active bookings
final activeBookingsProvider = FutureProvider<List<models.Booking>>((ref) async {
  try {
    final isOnline = ref.watch(isOnlineProvider);
    final repository = ref.watch(bookingRepositoryProvider(isOnline));
    final bookings = await repository.getActiveBookings();
    debugPrint('Active bookings provider: Loaded ${bookings.length} bookings');
    return bookings;
  } catch (e, stackTrace) {
    debugPrint('Error in activeBookingsProvider: $e');
    debugPrint('Stack trace: $stackTrace');
    // Return empty list instead of throwing to prevent UI from breaking
    return [];
  }
});

/// Provider for all bookings
final allBookingsProvider = FutureProvider<List<models.Booking>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final repository = ref.watch(bookingRepositoryProvider(isOnline));
  return repository.getBookings();
});


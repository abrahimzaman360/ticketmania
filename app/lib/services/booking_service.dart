import '../main.dart';
import '../models/booking.dart';
import '../models/ticket_type.dart';
import '../models/station.dart';
import 'package:uuid/uuid.dart';

class BookingService {
  final uuid = const Uuid();

  Future<List<Booking>> getActiveBookings() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('bookings')
          .select('''
            *,
            ticket_types:ticket_types(name),
            from_station:stations!bookings_from_station_id_fkey(name),
            to_station:stations!bookings_to_station_id_fkey(name)
          ''')
          .eq('user_id', userId)
          .or('status.eq.pending,status.eq.confirmed,status.eq.active')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) {
            final booking = Booking.fromJson(json);
            return Booking(
              id: booking.id,
              userId: booking.userId,
              ticketTypeId: booking.ticketTypeId,
              fromStationId: booking.fromStationId,
              toStationId: booking.toStationId,
              quantity: booking.quantity,
              totalPrice: booking.totalPrice,
              status: booking.status,
              qrCode: booking.qrCode,
              rfidToken: booking.rfidToken,
              validFrom: booking.validFrom,
              validUntil: booking.validUntil,
              validatedAt: booking.validatedAt,
              createdAt: booking.createdAt,
              updatedAt: booking.updatedAt,
              ticketTypeName: json['ticket_types']?['name'] as String?,
              fromStationName: json['from_station']?['name'] as String?,
              toStationName: json['to_station']?['name'] as String?,
            );
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch active bookings: $e');
    }
  }

  Future<Booking> createBooking({
    required String ticketTypeId,
    String? fromStationId,
    String? toStationId,
    int quantity = 1,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get ticket type to calculate price
      final ticketTypeResponse = await supabase
          .from('ticket_types')
          .select()
          .eq('id', ticketTypeId)
          .single();

      final ticketType = TicketType.fromJson(ticketTypeResponse);
      final totalPrice = ticketType.price * quantity;

      // Generate QR code
      final qrCode = uuid.v4();
      final rfidToken = uuid.v4();

      // Calculate validity
      DateTime? validFrom;
      DateTime? validUntil;

      if (ticketType.durationMinutes != null) {
        validFrom = DateTime.now().toUtc();
        validUntil = validFrom.add(Duration(minutes: ticketType.durationMinutes!));
      }

      final bookingData = {
        'user_id': userId,
        'ticket_type_id': ticketTypeId,
        'from_station_id': fromStationId,
        'to_station_id': toStationId,
        'quantity': quantity,
        'total_price': totalPrice,
        'status': 'pending',
        'qr_code': qrCode,
        'rfid_token': rfidToken,
        'valid_from': validFrom?.toIso8601String(),
        'valid_until': validUntil?.toIso8601String(),
      };

      final response = await supabase
          .from('bookings')
          .insert(bookingData)
          .select()
          .single();

      return Booking.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  Future<void> confirmBooking(String bookingId) async {
    try {
      await supabase
          .from('bookings')
          .update({'status': 'confirmed'})
          .eq('id', bookingId);
    } catch (e) {
      throw Exception('Failed to confirm booking: $e');
    }
  }

  Future<void> validateTicket(String bookingId, {
    required String validationType,
    String? deviceId,
    double? latitude,
    double? longitude,
    String? stationId,
  }) async {
    try {
      // Update booking status
      await supabase
          .from('bookings')
          .update({
            'status': 'active',
            'validated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', bookingId);

      // Create validation log
      await supabase.from('validation_logs').insert({
        'booking_id': bookingId,
        'validation_type': validationType,
        'device_id': deviceId,
        'location_latitude': latitude,
        'location_longitude': longitude,
        'station_id': stationId,
      });
    } catch (e) {
      throw Exception('Failed to validate ticket: $e');
    }
  }

  Future<List<TicketType>> getTicketTypes() async {
    try {
      final response = await supabase
          .from('ticket_types')
          .select()
          .eq('is_active', true)
          .order('price', ascending: true);

      return (response as List)
          .map((json) => TicketType.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch ticket types: $e');
    }
  }

  Future<List<Station>> getStations() async {
    try {
      final response = await supabase
          .from('stations')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Station.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch stations: $e');
    }
  }

  Future<List<Booking>> getAllBookings({
    String? filter, // 'all', 'family', 'used', 'expired'
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = supabase
          .from('bookings')
          .select('''
            *,
            ticket_types:ticket_types(name),
            from_station:stations!bookings_from_station_id_fkey(name),
            to_station:stations!bookings_to_station_id_fkey(name)
          ''')
          .eq('user_id', userId);

      // Apply filters
      switch (filter) {
        case 'family':
          query = query.gt('quantity', 1);
          break;
        case 'used':
          query = query.eq('status', 'used');
          break;
        case 'expired':
          query = query.eq('status', 'expired');
          break;
        case 'all':
        default:
          // No filter, get all
          break;
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) {
            final booking = Booking.fromJson(json);
            return Booking(
              id: booking.id,
              userId: booking.userId,
              ticketTypeId: booking.ticketTypeId,
              fromStationId: booking.fromStationId,
              toStationId: booking.toStationId,
              quantity: booking.quantity,
              totalPrice: booking.totalPrice,
              status: booking.status,
              qrCode: booking.qrCode,
              rfidToken: booking.rfidToken,
              validFrom: booking.validFrom,
              validUntil: booking.validUntil,
              validatedAt: booking.validatedAt,
              createdAt: booking.createdAt,
              updatedAt: booking.updatedAt,
              ticketTypeName: json['ticket_types']?['name'] as String?,
              fromStationName: json['from_station']?['name'] as String?,
              toStationName: json['to_station']?['name'] as String?,
            );
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }
}


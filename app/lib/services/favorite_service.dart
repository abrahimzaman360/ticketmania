import '../main.dart';
import '../models/favorite_ticket.dart';

class FavoriteService {
  Future<List<FavoriteTicket>> getFavorites() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('favorite_tickets')
          .select('''
            *,
            ticket_types:ticket_types(name, price),
            from_station:stations!favorite_tickets_from_station_id_fkey(name),
            to_station:stations!favorite_tickets_to_station_id_fkey(name)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => FavoriteTicket.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch favorites: $e');
    }
  }

  Future<void> addFavorite({
    required String ticketTypeId,
    String? fromStationId,
    String? toStationId,
    int quantity = 1,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase.from('favorite_tickets').insert({
        'user_id': userId,
        'ticket_type_id': ticketTypeId,
        'from_station_id': fromStationId,
        'to_station_id': toStationId,
        'quantity': quantity,
      });
    } catch (e) {
      throw Exception('Failed to add favorite: $e');
    }
  }

  Future<void> removeFavorite(String favoriteId) async {
    try {
      await supabase
          .from('favorite_tickets')
          .delete()
          .eq('id', favoriteId);
    } catch (e) {
      throw Exception('Failed to remove favorite: $e');
    }
  }

  Future<bool> isFavorite({
    required String ticketTypeId,
    String? fromStationId,
    String? toStationId,
    int? quantity,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Get all favorites matching the complete workflow
      final response = await supabase
          .from('favorite_tickets')
          .select('id, from_station_id, to_station_id, quantity')
          .eq('user_id', userId)
          .eq('ticket_type_id', ticketTypeId);

      final favorites = response as List;
      for (final fav in favorites) {
        final favFromStation = fav['from_station_id'] as String?;
        final favToStation = fav['to_station_id'] as String?;
        final favQuantity = fav['quantity'] as int?;
        
        // Match complete workflow: ticket type, stations, and quantity
        if (favFromStation == fromStationId && 
            favToStation == toStationId &&
            (quantity == null || favQuantity == quantity)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }
  
  Future<String?> getFavoriteId({
    required String ticketTypeId,
    String? fromStationId,
    String? toStationId,
    int? quantity,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await supabase
          .from('favorite_tickets')
          .select('id, from_station_id, to_station_id, quantity')
          .eq('user_id', userId)
          .eq('ticket_type_id', ticketTypeId);

      final favorites = response as List;
      for (final fav in favorites) {
        final favFromStation = fav['from_station_id'] as String?;
        final favToStation = fav['to_station_id'] as String?;
        final favQuantity = fav['quantity'] as int?;
        
        if (favFromStation == fromStationId && 
            favToStation == toStationId &&
            (quantity == null || favQuantity == quantity)) {
          return fav['id'] as String;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}


class FavoriteTicket {
  final String id;
  final String userId;
  final String ticketTypeId;
  final String? fromStationId;
  final String? toStationId;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data (loaded separately)
  final String? ticketTypeName;
  final String? fromStationName;
  final String? toStationName;
  final double? ticketPrice;

  FavoriteTicket({
    required this.id,
    required this.userId,
    required this.ticketTypeId,
    this.fromStationId,
    this.toStationId,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
    this.ticketTypeName,
    this.fromStationName,
    this.toStationName,
    this.ticketPrice,
  });

  factory FavoriteTicket.fromJson(Map<String, dynamic> json) {
    return FavoriteTicket(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      ticketTypeId: json['ticket_type_id'] as String,
      fromStationId: json['from_station_id'] as String?,
      toStationId: json['to_station_id'] as String?,
      quantity: json['quantity'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      ticketTypeName: json['ticket_types']?['name'] as String?,
      fromStationName: json['from_station']?['name'] as String?,
      toStationName: json['to_station']?['name'] as String?,
      ticketPrice: json['ticket_types']?['price'] != null
          ? (json['ticket_types']?['price'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'ticket_type_id': ticketTypeId,
      'from_station_id': fromStationId,
      'to_station_id': toStationId,
      'quantity': quantity,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}


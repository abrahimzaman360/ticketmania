class Booking {
  final String id;
  final String userId;
  final String ticketTypeId;
  final String? fromStationId;
  final String? toStationId;
  final int quantity;
  final double totalPrice;
  final BookingStatus status;
  final String? qrCode;
  final String? rfidToken;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? validatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data (loaded separately)
  final String? ticketTypeName;
  final String? fromStationName;
  final String? toStationName;

  Booking({
    required this.id,
    required this.userId,
    required this.ticketTypeId,
    this.fromStationId,
    this.toStationId,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    this.qrCode,
    this.rfidToken,
    this.validFrom,
    this.validUntil,
    this.validatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.ticketTypeName,
    this.fromStationName,
    this.toStationName,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      ticketTypeId: json['ticket_type_id'] as String,
      fromStationId: json['from_station_id'] as String?,
      toStationId: json['to_station_id'] as String?,
      quantity: json['quantity'] as int,
      totalPrice: (json['total_price'] as num).toDouble(),
      status: BookingStatus.fromString(json['status'] as String),
      qrCode: json['qr_code'] as String?,
      rfidToken: json['rfid_token'] as String?,
      validFrom: json['valid_from'] != null
          ? DateTime.parse(json['valid_from'] as String)
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : null,
      validatedAt: json['validated_at'] != null
          ? DateTime.parse(json['validated_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      ticketTypeName: json['ticket_type_name'] as String?,
      fromStationName: json['from_station_name'] as String?,
      toStationName: json['to_station_name'] as String?,
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
      'total_price': totalPrice,
      'status': status.value,
      'qr_code': qrCode,
      'rfid_token': rfidToken,
      'valid_from': validFrom?.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'validated_at': validatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isActive => status == BookingStatus.active;
  bool get isValid => isActive && (validUntil == null || validUntil!.isAfter(DateTime.now()));
}

enum BookingStatus {
  pending('pending'),
  confirmed('confirmed'),
  active('active'),
  used('used'),
  expired('expired'),
  cancelled('cancelled');

  final String value;
  const BookingStatus(this.value);

  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BookingStatus.pending,
    );
  }
}


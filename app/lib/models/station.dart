class Station {
  final String id;
  final String name;
  final String code;
  final double latitude;
  final double longitude;
  final String? city;
  final String country;
  final bool isActive;
  final DateTime createdAt;

  Station({
    required this.id,
    required this.name,
    required this.code,
    required this.latitude,
    required this.longitude,
    this.city,
    required this.country,
    required this.isActive,
    required this.createdAt,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      city: json['city'] as String?,
      country: json['country'] as String? ?? 'EU',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'country': country,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}


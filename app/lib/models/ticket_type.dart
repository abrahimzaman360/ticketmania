class TicketType {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int? durationMinutes;
  final ValidityType validityType;
  final String category;
  final bool isActive;
  final DateTime createdAt;

  TicketType({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.durationMinutes,
    required this.validityType,
    this.category = 'general',
    required this.isActive,
    required this.createdAt,
  });

  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      durationMinutes: json['duration_minutes'] as int?,
      validityType: ValidityType.fromString(json['validity_type'] as String),
      category: json['category'] as String? ?? 'general',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration_minutes': durationMinutes,
      'validity_type': validityType.value,
      'category': category,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedPrice => '€${price.toStringAsFixed(2)}';
  String get durationText {
    if (durationMinutes == null) return 'Single use';
    if (durationMinutes! < 60) return '$durationMinutes minutes';
    if (durationMinutes! < 1440) return '${durationMinutes! ~/ 60} hours';
    if (durationMinutes! < 10080) return '${durationMinutes! ~/ 1440} days';
    return '${durationMinutes! ~/ 10080} weeks';
  }
}

enum ValidityType {
  single('single'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  final String value;
  const ValidityType(this.value);

  static ValidityType fromString(String value) {
    return ValidityType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ValidityType.single,
    );
  }
}


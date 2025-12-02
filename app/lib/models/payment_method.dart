class PaymentMethod {
  final String id;
  final String userId;
  final PaymentMethodType type;
  final String? cardNumber; // Last 4 digits only
  final String? cardHolderName;
  final String? expiryMonth;
  final String? expiryYear;
  final String? brand; // Visa, Mastercard, etc.
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    this.cardNumber,
    this.cardHolderName,
    this.expiryMonth,
    this.expiryYear,
    this.brand,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: PaymentMethodType.fromString(json['type'] as String),
      cardNumber: json['card_number'] as String?,
      cardHolderName: json['card_holder_name'] as String?,
      expiryMonth: json['expiry_month'] as String?,
      expiryYear: json['expiry_year'] as String?,
      brand: json['brand'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.value,
      'card_number': cardNumber,
      'card_holder_name': cardHolderName,
      'expiry_month': expiryMonth,
      'expiry_year': expiryYear,
      'brand': brand,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get maskedCardNumber {
    if (cardNumber == null || cardNumber!.isEmpty) return '';
    if (cardNumber!.length <= 4) return cardNumber!;
    return '**** **** **** ${cardNumber!.substring(cardNumber!.length - 4)}';
  }

  String get displayName {
    switch (type) {
      case PaymentMethodType.card:
        return brand != null ? '$brand •••• ${cardNumber?.substring(cardNumber!.length - 4) ?? ""}' : 'Card •••• ${cardNumber?.substring(cardNumber!.length - 4) ?? ""}';
      case PaymentMethodType.paypal:
        return 'PayPal';
      case PaymentMethodType.applePay:
        return 'Apple Pay';
      case PaymentMethodType.googlePay:
        return 'Google Pay';
      case PaymentMethodType.wallet:
        return 'Wallet';
    }
  }
}

enum PaymentMethodType {
  card('card'),
  paypal('paypal'),
  applePay('apple_pay'),
  googlePay('google_pay'),
  wallet('wallet');

  final String value;
  const PaymentMethodType(this.value);

  static PaymentMethodType fromString(String value) {
    return PaymentMethodType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentMethodType.card,
    );
  }
}


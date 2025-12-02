class Wallet {
  final String id;
  final String userId;
  final double balance;
  final String currency;
  final bool autoTopupEnabled;
  final double autoTopupLimit;
  final double autoTopupAmount;
  final String? autoTopupPaymentMethodId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.currency,
    required this.autoTopupEnabled,
    required this.autoTopupLimit,
    required this.autoTopupAmount,
    this.autoTopupPaymentMethodId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      autoTopupEnabled: json['auto_topup_enabled'] as bool? ?? false,
      autoTopupLimit: (json['auto_topup_limit'] as num?)?.toDouble() ?? 10.0,
      autoTopupAmount: (json['auto_topup_amount'] as num?)?.toDouble() ?? 20.0,
      autoTopupPaymentMethodId: json['auto_topup_payment_method_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'currency': currency,
      'auto_topup_enabled': autoTopupEnabled,
      'auto_topup_limit': autoTopupLimit,
      'auto_topup_amount': autoTopupAmount,
      'auto_topup_payment_method_id': autoTopupPaymentMethodId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get needsTopup => balance <= autoTopupLimit && autoTopupEnabled;
}

class WalletTransaction {
  final String id;
  final String walletId;
  final double amount;
  final TransactionType type;
  final String? description;
  final String? paymentId;
  final String? bookingId;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.type,
    this.description,
    this.paymentId,
    this.bookingId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.fromString(json['transaction_type'] as String),
      description: json['description'] as String?,
      paymentId: json['payment_id'] as String?,
      bookingId: json['booking_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

enum TransactionType {
  credit('credit'),
  debit('debit'),
  refund('refund');

  final String value;
  const TransactionType(this.value);

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TransactionType.credit,
    );
  }
}


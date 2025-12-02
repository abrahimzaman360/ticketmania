import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/payment_method_repository.dart';
import '../providers/connectivity_provider.dart';
import '../models/payment_method.dart' as models;

/// Provider for payment methods
final paymentMethodsProvider = FutureProvider<List<models.PaymentMethod>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final repository = ref.watch(paymentMethodRepositoryProvider(isOnline));
  return repository.getPaymentMethods();
});


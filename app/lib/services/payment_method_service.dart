import '../main.dart';
import '../models/payment_method.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for PaymentMethodService (legacy support - use repository instead)
final paymentMethodServiceProvider = Provider<PaymentMethodService>((ref) {
  return PaymentMethodService();
});

/// Legacy service - use PaymentMethodRepository instead for offline-first support
class PaymentMethodService {
  final _uuid = const Uuid();

  /// Get all payment methods for the current user
  Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('payment_methods')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PaymentMethod.fromJson(json))
          .toList();
    } catch (e) {
      // If table doesn't exist, return empty list
      if (e.toString().contains('relation') ||
          e.toString().contains('does not exist')) {
        return [];
      }
      throw Exception('Failed to fetch payment methods: $e');
    }
  }

  /// Add a new payment method
  Future<PaymentMethod> addPaymentMethod({
    required PaymentMethodType type,
    String? cardNumber,
    String? cardHolderName,
    String? expiryMonth,
    String? expiryYear,
    String? brand,
    bool setAsDefault = false,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // If setting as default, unset other defaults
      if (setAsDefault) {
        await supabase
            .from('payment_methods')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      final paymentMethodId = _uuid.v4();
      final now = DateTime.now().toUtc();

      // Sanitize and prepare data for safe storage
      // Only store last 4 digits of card number (already done in AddPaymentMethodPage)
      // Card holder name is safe to store
      // Expiry dates are safe to store (month/year only)

      // Sanitize card holder name (remove special characters that could cause issues)
      String? sanitizedCardHolderName;
      if (cardHolderName != null) {
        sanitizedCardHolderName = cardHolderName.trim().replaceAll(
          RegExp(
            r'[<>"\'
            ']',
          ),
          '',
        );
      }

      final data = <String, dynamic>{
        'id': paymentMethodId,
        'user_id': userId,
        'type': type.value,
        // Only store last 4 digits for security
        'card_number': cardNumber?.length == 4 ? cardNumber : null,
        'card_holder_name': sanitizedCardHolderName,
        'expiry_month': expiryMonth?.trim(),
        'expiry_year': expiryYear?.trim(),
        'brand': brand?.trim(),
        'is_default': setAsDefault,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Remove null values to avoid database issues
      data.removeWhere((key, value) => value == null);

      final response = await supabase
          .from('payment_methods')
          .insert(data)
          .select()
          .single();

      return PaymentMethod.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add payment method: $e');
    }
  }

  /// Update a payment method
  Future<PaymentMethod> updatePaymentMethod({
    required String id,
    String? cardHolderName,
    String? expiryMonth,
    String? expiryYear,
    bool? setAsDefault,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // If setting as default, unset other defaults
      if (setAsDefault == true) {
        await supabase
            .from('payment_methods')
            .update({'is_default': false})
            .eq('user_id', userId)
            .neq('id', id);
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (cardHolderName != null) {
        updateData['card_holder_name'] = cardHolderName;
      }
      if (expiryMonth != null) {
        updateData['expiry_month'] = expiryMonth;
      }
      if (expiryYear != null) {
        updateData['expiry_year'] = expiryYear;
      }
      if (setAsDefault != null) {
        updateData['is_default'] = setAsDefault;
      }

      final response = await supabase
          .from('payment_methods')
          .update(updateData)
          .eq('id', id)
          .eq('user_id', userId)
          .select()
          .single();

      return PaymentMethod.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update payment method: $e');
    }
  }

  /// Delete a payment method
  Future<void> deletePaymentMethod(String id) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('payment_methods')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete payment method: $e');
    }
  }

  /// Set a payment method as default
  Future<void> setDefaultPaymentMethod(String id) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Unset all defaults
      await supabase
          .from('payment_methods')
          .update({'is_default': false})
          .eq('user_id', userId);

      // Set new default
      await supabase
          .from('payment_methods')
          .update({
            'is_default': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to set default payment method: $e');
    }
  }
}

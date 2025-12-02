import '../main.dart';
import '../models/wallet.dart';

class WalletService {
  Future<Wallet> getWallet() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .single();

      return Wallet.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch wallet: $e');
    }
  }

  Future<void> addMoney(double amount, {String? paymentId}) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get current wallet
      final wallet = await getWallet();

      // Update wallet balance
      await supabase
          .from('wallets')
          .update({'balance': wallet.balance + amount})
          .eq('id', wallet.id);

      // Create transaction
      await supabase.from('wallet_transactions').insert({
        'wallet_id': wallet.id,
        'amount': amount,
        'transaction_type': 'credit',
        'description': 'Manual top-up',
        'payment_id': paymentId,
      });
    } catch (e) {
      throw Exception('Failed to add money: $e');
    }
  }

  Future<void> deductMoney(double amount, {String? bookingId, String? description}) async {
    try {
      final wallet = await getWallet();

      if (wallet.balance < amount) {
        throw Exception('Insufficient balance');
      }

      // Update wallet balance
      await supabase
          .from('wallets')
          .update({'balance': wallet.balance - amount})
          .eq('id', wallet.id);

      // Create transaction
      await supabase.from('wallet_transactions').insert({
        'wallet_id': wallet.id,
        'amount': amount,
        'transaction_type': 'debit',
        'description': description ?? 'Payment',
        'booking_id': bookingId,
      });

      // Check if auto top-up is needed
      final updatedWallet = await getWallet();
      if (updatedWallet.needsTopup) {
        await _autoTopup(updatedWallet, paymentMethodId: updatedWallet.autoTopupPaymentMethodId);
      }
    } catch (e) {
      throw Exception('Failed to deduct money: $e');
    }
  }

  Future<void> _autoTopup(Wallet wallet, {String? paymentMethodId}) async {
    try {
      // In a real app, you would process the payment through the payment method here
      // For now, we'll just add the money directly
      
      // Add auto top-up amount
      await supabase
          .from('wallets')
          .update({'balance': wallet.balance + wallet.autoTopupAmount})
          .eq('id', wallet.id);

      // Create transaction with payment method ID if available
      await supabase.from('wallet_transactions').insert({
        'wallet_id': wallet.id,
        'amount': wallet.autoTopupAmount,
        'transaction_type': 'credit',
        'description': 'Auto top-up',
        'payment_id': paymentMethodId,
      });
    } catch (e) {
      throw Exception('Failed to auto top-up: $e');
    }
  }

  Future<void> updateAutoTopupSettings({
    required bool enabled,
    double? limit,
    double? amount,
    String? paymentMethodId,
  }) async {
    try {
      final wallet = await getWallet();
      final updates = <String, dynamic>{
        'auto_topup_enabled': enabled,
      };

      if (limit != null) updates['auto_topup_limit'] = limit;
      if (amount != null) updates['auto_topup_amount'] = amount;
      if (paymentMethodId != null) {
        // Store payment method ID for auto top-up
        // Note: This assumes the wallets table has an auto_topup_payment_method_id column
        // If not, you may need to store this in a separate table or user preferences
        updates['auto_topup_payment_method_id'] = paymentMethodId;
      }

      await supabase
          .from('wallets')
          .update(updates)
          .eq('id', wallet.id);
    } catch (e) {
      // If column doesn't exist, just update without payment method ID
      final wallet = await getWallet();
      final updates = <String, dynamic>{
        'auto_topup_enabled': enabled,
      };
      if (limit != null) updates['auto_topup_limit'] = limit;
      if (amount != null) updates['auto_topup_amount'] = amount;
      
      await supabase
          .from('wallets')
          .update(updates)
          .eq('id', wallet.id);
    }
  }

  Future<List<WalletTransaction>> getTransactions({int limit = 50}) async {
    try {
      final wallet = await getWallet();

      final response = await supabase
          .from('wallet_transactions')
          .select()
          .eq('wallet_id', wallet.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => WalletTransaction.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }
}


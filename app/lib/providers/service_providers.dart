import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/booking_service.dart';
import '../services/wallet_service.dart';
import '../models/wallet.dart';
import '../repositories/wallet_repository.dart';
import '../providers/connectivity_provider.dart';

/// Provider for BookingService
final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService();
});

/// Provider for WalletService
final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

/// Provider for wallet balance - works offline, uses cached data
final walletBalanceProvider = FutureProvider<double>((ref) async {
  try {
    final isOnline = ref.watch(isOnlineProvider);
    final repository = ref.watch(walletRepositoryProvider(isOnline));
    final balance = await repository.getWalletBalance();
    debugPrint('Wallet balance provider: Loaded balance $balance (offline: ${!isOnline})');
    return balance;
  } catch (e, stackTrace) {
    debugPrint('Error in walletBalanceProvider: $e');
    debugPrint('Stack trace: $stackTrace');
    // Return 0.0 instead of throwing to prevent UI from breaking
    return 0.0;
  }
});

/// Provider for full wallet data - works offline, uses cached data
final walletProvider = FutureProvider<Wallet?>((ref) async {
  try {
    final isOnline = ref.watch(isOnlineProvider);
    final repository = ref.watch(walletRepositoryProvider(isOnline));
    final wallet = await repository.getWallet();
    return wallet;
  } catch (e, stackTrace) {
    debugPrint('Error in walletProvider: $e');
    debugPrint('Stack trace: $stackTrace');
    return null;
  }
});


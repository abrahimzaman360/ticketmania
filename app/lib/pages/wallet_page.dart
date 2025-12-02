import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_service.dart';
import '../services/security_service.dart';
import '../models/wallet.dart';
import '../models/payment_method.dart';
import '../providers/payment_method_providers.dart';
import '../providers/connectivity_provider.dart';
import '../providers/service_providers.dart';
import '../widgets/offline_indicator.dart';
import '../utils/error_handler.dart';
import 'all_transactions_page.dart';
import 'payment_methods_page.dart';
import 'pin_setup_page.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  final WalletService _walletService = WalletService();
  final SecurityService _securityService = SecurityService();
  List<WalletTransaction> _transactions = [];
  bool _isLoadingTransactions = false;

  /// Authenticate before accessing payment methods
  Future<bool> _authenticateForPaymentMethods() async {
    // First, try device security (Face ID/Touch ID/Fingerprint/Device PIN)
    final biometricAvailable = await _securityService.isBiometricAvailable();

    if (biometricAvailable) {
      // Try device security authentication
      final authenticated = await _securityService.authenticate(
        reason: 'Authenticate to access payment methods',
      );
      if (authenticated) {
        return true;
      }
      // If device security fails, fall through to custom PIN
    }

    // Fallback to custom PIN if device security is not available or fails
    final pinEnabled = await _securityService.isPinEnabled();
    if (pinEnabled) {
      if (!mounted) return false;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PinSetupPage(isSetup: false),
          fullscreenDialog: true,
        ),
      );
      return result ?? false;
    }

    // If no security is set up, prompt to set up PIN
    if (!mounted) return false;
    final setup = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Security Required'),
        content: const Text(
          'You must set up a PIN to access payment methods. This is required for security.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set Up PIN'),
          ),
        ],
      ),
    );

    if (setup == true) {
      if (!mounted) return false;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PinSetupPage(isSetup: true),
          fullscreenDialog: true,
        ),
      );
      if (result == true) {
        return true;
      }
    }

    return false;
  }

  /// Navigate to payment methods page with authentication
  Future<void> _navigateToPaymentMethods() async {
    final authenticated = await _authenticateForPaymentMethods();
    if (!authenticated || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentMethodsPage()),
    );
    ref.invalidate(paymentMethodsProvider);
  }

  @override
  void initState() {
    super.initState();
    // Wallet is loaded via provider, no need to call _loadWallet here
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoadingTransactions = true);
    try {
      final transactions = await _walletService.getTransactions(limit: 8);
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoadingTransactions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTransactions = false);
      }
    }
  }

  void _showTransactionDetails(WalletTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(transaction.description ?? 'Transaction Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Type',
              transaction.type == TransactionType.credit ? 'Credit' : 'Debit',
            ),
            _buildDetailRow(
              'Amount',
              '€${transaction.amount.toStringAsFixed(2)}',
            ),
            _buildDetailRow('Date', _formatDateTime(transaction.createdAt)),
            if (transaction.description != null)
              _buildDetailRow('Description', transaction.description!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _showAddMoneyDialog() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      ErrorHandler.showInfo(
        context,
        'Wallet actions are not available offline. Please connect to the internet to add money.',
      );
      return;
    }

    final amountController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

          return paymentMethodsAsync.when(
            data: (paymentMethods) {
              // Variable declared OUTSIDE builder to persist state
              PaymentMethod? selectedPaymentMethod = paymentMethods.isNotEmpty
                  ? paymentMethods.firstWhere(
                      (m) => m.isDefault,
                      orElse: () => paymentMethods.first,
                    )
                  : null;

              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return Dialog(
                    insetPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Money',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount (€)',
                              prefixText: '€',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Payment Method',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (paymentMethods.isNotEmpty) ...[
                            ...paymentMethods.map(
                              (method) => InkWell(
                                onTap: () => setDialogState(
                                  () => selectedPaymentMethod = method,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          selectedPaymentMethod?.id == method.id
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.grey.shade300,
                                      width:
                                          selectedPaymentMethod?.id == method.id
                                          ? 2
                                          : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<PaymentMethod>(
                                        value: method,
                                        groupValue: selectedPaymentMethod,
                                        onChanged: (v) => setDialogState(
                                          () => selectedPaymentMethod = v,
                                        ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Icon(
                                        _getPaymentMethodIcon(method.type),
                                        size: 18,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          method.type == PaymentMethodType.card
                                              ? '${method.brand ?? 'Card'} •••• ${method.cardNumber ?? '****'}'
                                              : method.displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      if (method.isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Default',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _navigateToPaymentMethods();
                              },
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text(
                                'Manage Payment Methods',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.payment,
                                    color: Colors.orange.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'No payment methods',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Add one to continue',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _navigateToPaymentMethods();
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Payment Method'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  final amount = double.tryParse(
                                    amountController.text,
                                  );
                                  if (amount != null && amount > 0) {
                                    if (paymentMethods.isEmpty) {
                                      Navigator.pop(context);
                                      _navigateToPaymentMethods();
                                    } else {
                                      Navigator.pop(context, {
                                        'amount': amount,
                                        'paymentMethod': selectedPaymentMethod,
                                      });
                                    }
                                  }
                                },
                                child: const Text('Add Money'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Loading...'),
                  ],
                ),
              ),
            ),
            error: (error, stack) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Error',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load payment methods',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      final amount = result['amount'] as double?;
      if (amount == null) return;

      final paymentMethod = result['paymentMethod'] as PaymentMethod?;

      try {
        await _walletService.addMoney(amount, paymentId: paymentMethod?.id);
        ref.invalidate(walletProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added €${amount.toStringAsFixed(2)}${paymentMethod != null ? " using ${paymentMethod.displayName}" : ""}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, e);
        }
      }
    }
  }

  Future<void> _showAutoTopupSettings() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      ErrorHandler.showInfo(
        context,
        'Wallet actions are not available offline. Please connect to the internet to change auto top-up settings.',
      );
      return;
    }

    final walletAsync = ref.read(walletProvider);
    final wallet = await walletAsync.when(
      data: (w) => w,
      loading: () => null,
      error: (_, __) => null,
    );

    if (wallet == null) return;

    final limitController = TextEditingController(
      text: wallet.autoTopupLimit.toStringAsFixed(2),
    );
    final amountController = TextEditingController(
      text: wallet.autoTopupAmount.toStringAsFixed(2),
    );
    final initialEnabled = wallet.autoTopupEnabled;
    final initialPaymentMethodId = wallet.autoTopupPaymentMethodId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

          return paymentMethodsAsync.when(
            data: (paymentMethods) {
              PaymentMethod? initialSelectedPaymentMethod;
              if (paymentMethods.isNotEmpty) {
                if (initialPaymentMethodId != null) {
                  initialSelectedPaymentMethod = paymentMethods.firstWhere(
                    (m) => m.id == initialPaymentMethodId,
                    orElse: () => paymentMethods.firstWhere(
                      (m) => m.isDefault,
                      orElse: () => paymentMethods.first,
                    ),
                  );
                } else {
                  initialSelectedPaymentMethod = paymentMethods.firstWhere(
                    (m) => m.isDefault,
                    orElse: () => paymentMethods.first,
                  );
                }
              }

              // Variables declared OUTSIDE builder to persist state
              bool enabled = initialEnabled;
              PaymentMethod? selectedPaymentMethod =
                  initialSelectedPaymentMethod;

              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return Dialog(
                    insetPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto Top-up Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Enable Auto Top-up',
                                  style: TextStyle(fontSize: 14),
                                ),
                                Switch(
                                  value: enabled,
                                  onChanged: (v) =>
                                      setDialogState(() => enabled = v),
                                ),
                              ],
                            ),
                            if (enabled) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: limitController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'When balance falls below (€)',
                                  prefixText: '€',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Top-up amount (€)',
                                  prefixText: '€',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Payment Method',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (paymentMethods.isNotEmpty) ...[
                                ...paymentMethods.map(
                                  (method) => InkWell(
                                    onTap: () => setDialogState(
                                      () => selectedPaymentMethod = method,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              selectedPaymentMethod?.id ==
                                                  method.id
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Colors.grey.shade300,
                                          width:
                                              selectedPaymentMethod?.id ==
                                                  method.id
                                              ? 2
                                              : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Radio<PaymentMethod>(
                                            value: method,
                                            groupValue: selectedPaymentMethod,
                                            onChanged: (v) => setDialogState(
                                              () => selectedPaymentMethod = v,
                                            ),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          Icon(
                                            _getPaymentMethodIcon(method.type),
                                            size: 18,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              method.type ==
                                                      PaymentMethodType.card
                                                  ? '${method.brand ?? 'Card'} •••• ${method.cardNumber ?? '****'}'
                                                  : method.displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          if (method.isDefault)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Default',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _navigateToPaymentMethods();
                                  },
                                  icon: const Icon(Icons.settings, size: 16),
                                  label: const Text(
                                    'Manage Payment Methods',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.payment,
                                        color: Colors.orange.shade700,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'No payment methods',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Add one to enable auto top-up',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _navigateToPaymentMethods();
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add Payment Method'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    if (enabled && paymentMethods.isEmpty) {
                                      Navigator.pop(context);
                                      _navigateToPaymentMethods();
                                    } else {
                                      Navigator.pop(context, {
                                        'enabled': enabled,
                                        'limit': double.tryParse(
                                          limitController.text,
                                        ),
                                        'amount': double.tryParse(
                                          amountController.text,
                                        ),
                                        'paymentMethod': selectedPaymentMethod,
                                      });
                                    }
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Loading...'),
                  ],
                ),
              ),
            ),
            error: (error, stack) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Error',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load payment methods',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      final enabled = result['enabled'] as bool;
      final limit = result['limit'] as double?;
      final amount = result['amount'] as double?;
      final selectedPaymentMethod = result['paymentMethod'] as PaymentMethod?;

      try {
        await _walletService.updateAutoTopupSettings(
          enabled: enabled,
          limit: limit,
          amount: amount,
          paymentMethodId: selectedPaymentMethod?.id,
        );
        ref.invalidate(walletProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto top-up settings updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOnline = ref.watch(isOnlineProvider);
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet'), elevation: 0),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: walletAsync.when(
              data: (wallet) {
                if (wallet == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No wallet found',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(walletProvider);
                    await Future.delayed(const Duration(milliseconds: 100));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Balance Card with gradient
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.withValues(alpha: 0.8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Balance',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 24,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '€${wallet.balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!isOnline) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cloud_off_outlined,
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Viewing cached balance',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (wallet.autoTopupEnabled) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.autorenew,
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Auto top-up enabled',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isOnline
                                      ? _showAddMoneyDialog
                                      : () {
                                          ErrorHandler.showInfo(
                                            context,
                                            'Wallet actions are not available offline. Please connect to the internet to add money.',
                                          );
                                        },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Money'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isOnline
                                      ? _showAutoTopupSettings
                                      : () {
                                          ErrorHandler.showInfo(
                                            context,
                                            'Wallet actions are not available offline. Please connect to the internet to change auto top-up settings.',
                                          );
                                        },
                                  icon: const Icon(Icons.settings),
                                  label: const Text('Auto Top-up'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Recent Transactions Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Transactions',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AllTransactionsPage(
                                        walletService: _walletService,
                                      ),
                                    ),
                                  ).then((_) {
                                    _loadTransactions();
                                  });
                                },
                                child: const Text('View All'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Transactions List
                        if (_isLoadingTransactions)
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_transactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions yet',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your transaction history will appear here',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ..._transactions.map(
                            (transaction) => Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      transaction.type == TransactionType.credit
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  child: Icon(
                                    transaction.type == TransactionType.credit
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color:
                                        transaction.type ==
                                            TransactionType.credit
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  transaction.description ?? 'Transaction',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  _formatDateTime(transaction.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: Text(
                                  '${transaction.type == TransactionType.credit ? '+' : '-'}€${transaction.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color:
                                        transaction.type ==
                                            TransactionType.credit
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                onTap: () =>
                                    _showTransactionDetails(transaction),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                debugPrint('Error loading wallet: $error');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load wallet',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(walletProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentMethodIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.card:
        return Icons.credit_card;
      case PaymentMethodType.paypal:
        return Icons.payment;
      case PaymentMethodType.applePay:
        return Icons.apple;
      case PaymentMethodType.googlePay:
        return Icons.g_mobiledata;
      case PaymentMethodType.wallet:
        return Icons.account_balance_wallet;
    }
  }
}

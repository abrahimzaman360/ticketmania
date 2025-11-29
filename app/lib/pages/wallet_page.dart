import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../models/wallet.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final WalletService _walletService = WalletService();
  Wallet? _wallet;
  bool _isLoading = true;
  List<WalletTransaction> _transactions = [];
  bool _isLoadingTransactions = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    try {
      final wallet = await _walletService.getWallet();
      setState(() {
        _wallet = wallet;
        _isLoading = false;
      });
      // Load transactions after wallet is loaded
      _loadTransactions();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading wallet: $e')),
        );
      }
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoadingTransactions = true);
    try {
      final transactions = await _walletService.getTransactions(limit: 10);
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

  Future<void> _showAddMoneyDialog() async {
    final amountController = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Money'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (€)',
            prefixText: '€',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context, amount);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _walletService.addMoney(result);
        _loadWallet(); // This will also reload transactions
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added €${result.toStringAsFixed(2)}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _showAutoTopupSettings() async {
    if (_wallet == null) return;

    final limitController = TextEditingController(
      text: _wallet!.autoTopupLimit.toStringAsFixed(2),
    );
    final amountController = TextEditingController(
      text: _wallet!.autoTopupAmount.toStringAsFixed(2),
    );
    bool enabled = _wallet!.autoTopupEnabled;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Auto Top-up Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Enable Auto Top-up'),
                value: enabled,
                onChanged: (value) {
                  setState(() => enabled = value);
                },
              ),
              if (enabled) ...[
                TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Top-up when balance falls below (€)',
                    prefixText: '€',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Top-up amount (€)',
                    prefixText: '€',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await _walletService.updateAutoTopupSettings(
          enabled: enabled,
          limit: double.tryParse(limitController.text),
          amount: double.tryParse(amountController.text),
        );
        _loadWallet();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wallet == null
              ? const Center(child: Text('No wallet found'))
              : RefreshIndicator(
                  onRefresh: _loadWallet,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Balance Card
                        Card(
                          elevation: 4,
                          color: Theme.of(context).colorScheme.primary,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                Text(
                                  'Balance',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.white70,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '€${_wallet!.balance.toStringAsFixed(2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _showAddMoneyDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Money'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor:
                                            Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _showAutoTopupSettings,
                                      icon: const Icon(Icons.settings),
                                      label: const Text('Auto Top-up'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Auto Top-up Status
                        if (_wallet!.autoTopupEnabled)
                          Card(
                            color: Colors.blue[50],
                            child: ListTile(
                              leading: Icon(Icons.auto_awesome,
                                  color: Colors.blue[700]),
                              title: const Text('Auto Top-up Enabled'),
                              subtitle: Text(
                                'Top-up €${_wallet!.autoTopupAmount.toStringAsFixed(2)} when balance falls below €${_wallet!.autoTopupLimit.toStringAsFixed(2)}',
                              ),
                              trailing: Switch(
                                value: _wallet!.autoTopupEnabled,
                                onChanged: (value) async {
                                  await _walletService.updateAutoTopupSettings(
                                    enabled: value,
                                  );
                                  _loadWallet();
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        // Recent Transactions
                        Text(
                          'Recent Transactions',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _isLoadingTransactions
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _transactions.isEmpty
                                ? const Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Text('No transactions yet'),
                                    ),
                                  )
                                : Column(
                                    children: _transactions.map((transaction) {
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: transaction.type ==
                                                    TransactionType.credit
                                                ? Colors.green
                                                : Colors.red,
                                            child: Icon(
                                              transaction.type ==
                                                      TransactionType.credit
                                                  ? Icons.add
                                                  : Icons.remove,
                                              color: Colors.white,
                                            ),
                                          ),
                                          title: Text(transaction.description ?? ''),
                                          subtitle: Text(
                                            transaction.createdAt.toString().split('.')[0],
                                          ),
                                          trailing: Text(
                                            '${transaction.type == TransactionType.credit ? '+' : '-'}€${transaction.amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: transaction.type ==
                                                      TransactionType.credit
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ],
                    ),
                  ),
                ),
    );
  }
}


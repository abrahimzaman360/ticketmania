import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/payment_method_repository.dart';
import '../models/payment_method.dart';
import '../providers/connectivity_provider.dart';

class AddPaymentMethodPage extends ConsumerStatefulWidget {
  const AddPaymentMethodPage({super.key});

  @override
  ConsumerState<AddPaymentMethodPage> createState() => _AddPaymentMethodPageState();
}

class _AddPaymentMethodPageState extends ConsumerState<AddPaymentMethodPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _isLoading = false;
  bool _setAsDefault = false;
  PaymentMethodType _selectedType = PaymentMethodType.card;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String _detectCardBrand(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return 'Card';
    
    if (cleaned.startsWith('4')) return 'Visa';
    if (cleaned.startsWith('5') || cleaned.startsWith('2')) return 'Mastercard';
    if (cleaned.startsWith('3')) return 'American Express';
    if (cleaned.startsWith('6')) return 'Discover';
    return 'Card';
  }

  Future<void> _savePaymentMethod() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      // For now, we'll create fake payment methods
      // In a real app, you'd integrate with a payment processor like Stripe
      
      String? cardNumber;
      String? cardHolderName;
      String? expiryMonth;
      String? expiryYear;
      String? brand;

      if (_selectedType == PaymentMethodType.card) {
        final cleanedNumber = _cardNumberController.text.replaceAll(RegExp(r'[^0-9]'), '');
        // Store only last 4 digits for security
        cardNumber = cleanedNumber.length >= 4 
            ? cleanedNumber.substring(cleanedNumber.length - 4)
            : cleanedNumber;
        cardHolderName = _cardHolderController.text.trim();
        expiryMonth = _expiryMonthController.text.trim().padLeft(2, '0');
        expiryYear = _expiryYearController.text.trim();
        brand = _detectCardBrand(_cardNumberController.text);
      }

      final isOnline = ref.read(isOnlineProvider);
      final repository = ref.read(paymentMethodRepositoryProvider(isOnline));
      await repository.addPaymentMethod(
        type: _selectedType,
        cardNumber: cardNumber,
        cardHolderName: cardHolderName,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        brand: brand,
        setAsDefault: _setAsDefault,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment method added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding payment method: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Payment Method'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Method Type Selection
              Text(
                'Payment Method Type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<PaymentMethodType>(
                segments: const [
                  ButtonSegment(
                    value: PaymentMethodType.card,
                    label: Text('Card'),
                    icon: Icon(Icons.credit_card),
                  ),
                  ButtonSegment(
                    value: PaymentMethodType.paypal,
                    label: Text('PayPal'),
                    icon: Icon(Icons.account_balance_wallet),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<PaymentMethodType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Card Details (only show for card type)
              if (_selectedType == PaymentMethodType.card) ...[
                // Card Number
                TextFormField(
                  controller: _cardNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Card Number',
                    hintText: '1234 5678 9012 3456',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(19),
                    CardNumberFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter card number';
                    }
                    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (cleaned.length < 13 || cleaned.length > 19) {
                      return 'Please enter a valid card number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Card Holder Name
                TextFormField(
                  controller: _cardHolderController,
                  decoration: const InputDecoration(
                    labelText: 'Card Holder Name',
                    hintText: 'John Doe',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter card holder name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Expiry Date and CVV Row
                Row(
                  children: [
                    // Expiry Month
                    Expanded(
                      child: TextFormField(
                        controller: _expiryMonthController,
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          hintText: 'MM',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'MM';
                          }
                          final month = int.tryParse(value);
                          if (month == null || month < 1 || month > 12) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Expiry Year
                    Expanded(
                      child: TextFormField(
                        controller: _expiryYearController,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          hintText: 'YYYY',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'YYYY';
                          }
                          final year = int.tryParse(value);
                          if (year == null || year < DateTime.now().year) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // CVV
                    Expanded(
                      child: TextFormField(
                        controller: _cvvController,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          hintText: '123',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'CVV';
                          }
                          if (value.length < 3) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Set as Default
              SwitchListTile(
                title: const Text('Set as default payment method'),
                subtitle: const Text('Use this payment method by default'),
                value: _setAsDefault,
                onChanged: (value) {
                  setState(() {
                    _setAsDefault = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePaymentMethod,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Payment Method'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatter for card numbers (adds spaces every 4 digits)
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}


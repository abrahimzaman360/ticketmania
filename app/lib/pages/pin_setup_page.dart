import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';

class PinSetupPage extends StatefulWidget {
  final bool isSetup; // true for setup, false for verification
  final Function(String)? onVerified;
  final int?
  currentFailedAttempts; // Current failed attempts for status display

  const PinSetupPage({
    super.key,
    this.isSetup = true,
    this.onVerified,
    this.currentFailedAttempts,
  });

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final SecurityService _securityService = SecurityService();
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;
  int _currentFailedAttempts =
      0; // Track current failed attempts for status display

  @override
  void initState() {
    super.initState();
    // Initialize failed attempts from parameter
    _currentFailedAttempts = widget.currentFailedAttempts ?? 0;
    // Auto-focus first field when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onDigitEntered(int index, String value) {
    if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    if (value.length > 1) {
      // Handle paste
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '').split('');
      for (int i = 0; i < 4 && (index + i) < _controllers.length; i++) {
        if (i < digits.length) {
          _controllers[index + i].text = digits[i];
        }
      }
      if (index + digits.length >= 4) {
        _focusNodes[3].unfocus();
        _checkPin();
      } else {
        _focusNodes[index + digits.length].requestFocus();
      }
      return;
    }

    if (index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      _checkPin();
    }
  }

  void _checkPin() {
    final pin = _controllers.map((c) => c.text).join();
    if (pin.length != 4) return;

    setState(() {
      _errorMessage = null;
    });

    if (widget.isSetup) {
      if (!_isConfirming) {
        setState(() {
          _pin = pin;
          _isConfirming = true;
        });
        // Clear controllers
        for (var controller in _controllers) {
          controller.clear();
        }
        // Auto-focus first field after state update
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _focusNodes[0].requestFocus();
          }
        });
      } else {
        _confirmPin = pin;
        if (_pin == _confirmPin) {
          _savePin();
        } else {
          setState(() {
            _errorMessage = 'PINs do not match. Please try again.';
            _isConfirming = false;
            _pin = '';
            _confirmPin = '';
          });
          for (var controller in _controllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();
        }
      }
    } else {
      _verifyPin(pin);
    }
  }

  Future<void> _savePin() async {
    final success = await _securityService.setPin(_pin);
    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN set successfully')));
      } else {
        setState(() {
          _errorMessage = 'Failed to save PIN. Please try again.';
        });
      }
    }
  }

  Future<void> _verifyPin(String pin) async {
    // Check for lockout before verifying PIN
    final isLocked = await _securityService.isPaymentMethodsLocked();
    if (isLocked) {
      final remainingSeconds = await _securityService
          .getRemainingLockoutSeconds();
      if (mounted) {
        // Show lockout message and close
        final hours = remainingSeconds ~/ 3600;
        final minutes = (remainingSeconds % 3600) ~/ 60;
        final seconds = remainingSeconds % 60;
        String timeRemaining;
        if (hours > 0) {
          timeRemaining = '${hours}h ${minutes}m';
        } else if (minutes > 0) {
          timeRemaining = '${minutes}m ${seconds}s';
        } else {
          timeRemaining = '${seconds}s';
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock_clock, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Payment System Disabled',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment methods are temporarily disabled due to 3 failed authentication attempts.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Time remaining:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeRemaining,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Payment methods will be available again after 1 hour from the last failed attempt.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop(false);
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    final isValid = await _securityService.verifyPin(pin);
    if (mounted) {
      if (isValid) {
        // Reset failed attempts on successful verification
        await _securityService.resetFailedAttempts();
        if (widget.onVerified != null) {
          widget.onVerified!(pin);
        }
        // ignore: use_build_context_synchronously
        Navigator.pop(context, true);
      } else {
        // Increment failed attempts on failure
        await _securityService.incrementFailedAttempts();
        final newFailedAttempts = await _securityService.getFailedAttempts();

        // Update state to reflect new failed attempts
        if (mounted) {
          setState(() {
            _currentFailedAttempts = newFailedAttempts;
          });
        }

        // Check if locked after this failure
        final isNowLocked = await _securityService.isPaymentMethodsLocked();

        if (isNowLocked) {
          // System is now locked - show lockout message
          final remainingSeconds = await _securityService
              .getRemainingLockoutSeconds();
          final hours = remainingSeconds ~/ 3600;
          final minutes = (remainingSeconds % 3600) ~/ 60;
          final seconds = remainingSeconds % 60;
          String timeRemaining;
          if (hours > 0) {
            timeRemaining = '${hours}h ${minutes}m';
          } else if (minutes > 0) {
            timeRemaining = '${minutes}m ${seconds}s';
          } else {
            timeRemaining = '${seconds}s';
          }

          showDialog(
            // ignore: use_build_context_synchronously
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => PopScope(
              canPop: false,
              child: AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.lock_clock, color: Colors.red, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Payment System Disabled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment methods are temporarily disabled due to 3 failed authentication attempts.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.red.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Time remaining:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeRemaining,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment methods will be available again after 1 hour from the last failed attempt.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop(false);
                    },
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Update error message with remaining attempts
          final remainingAttempts = 3 - newFailedAttempts;
          setState(() {
            _errorMessage = remainingAttempts > 0
                ? 'Incorrect PIN. $remainingAttempts attempt${remainingAttempts != 1 ? 's' : ''} remaining.'
                : 'Incorrect PIN. Payment methods will be locked after this attempt.';
          });
          for (var controller in _controllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isSetup ? 'Set PIN' : 'Enter PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                widget.isSetup
                    ? (_isConfirming ? 'Confirm PIN' : 'Enter a 4-digit PIN')
                    : 'Enter your PIN to continue',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (widget.isSetup && !_isConfirming)
                Text(
                  'This PIN will be used to secure your payment methods',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              // Show failed attempts status for verification mode
              if (!widget.isSetup && _currentFailedAttempts > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _currentFailedAttempts >= 2
                        ? Colors.orange.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentFailedAttempts >= 2
                          ? Colors.orange.shade300
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: _currentFailedAttempts >= 2
                            ? Colors.orange.shade700
                            : Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Attempts: $_currentFailedAttempts / 3',
                        style: TextStyle(
                          color: _currentFailedAttempts >= 2
                              ? Colors.orange.shade900
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      obscureText: true,
                      autofocus: index == 0,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onDigitEntered(index, value),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                    ),
                  );
                }),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              if (widget.isSetup && _isConfirming)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isConfirming = false;
                      _pin = '';
                      _confirmPin = '';
                      _errorMessage = null;
                    });
                    for (var controller in _controllers) {
                      controller.clear();
                    }
                    _focusNodes[0].requestFocus();
                  },
                  child: const Text('Start Over'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

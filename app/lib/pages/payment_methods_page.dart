import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../repositories/payment_method_repository.dart';
import '../models/payment_method.dart';
import '../services/security_service.dart';
import '../providers/payment_method_providers.dart';
import '../providers/connectivity_provider.dart';
import '../pages/pin_setup_page.dart';
import 'add_payment_method_page.dart';

class PaymentMethodsPage extends ConsumerStatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  ConsumerState<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends ConsumerState<PaymentMethodsPage>
    with WidgetsBindingObserver {
  final SecurityService _securityService = SecurityService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isAuthenticating = true;
  bool _authenticationAttempted = false;

  @override
  void initState() {
    super.initState();
    // Observe app lifecycle to re-authenticate when app comes back to foreground
    WidgetsBinding.instance.addObserver(this);
    // Wait for widget tree to be built before showing dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _authenticateAndLoad();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // SECURITY: If app comes back to foreground, ALWAYS check lockout and re-authenticate
    // This ensures payment methods are never accessible without recent authentication
    if (state == AppLifecycleState.resumed && !_isAuthenticating) {
      // CRITICAL: Always check lockout first, regardless of authentication state
      // Lock content immediately to prevent any bypass
      setState(() {
        _isAuthenticated = false; // Lock content immediately
        _isAuthenticating = true; // Show loading while checking
      });
      // Re-authenticate when app comes back to foreground
      // This will check lockout first before allowing authentication
      _authenticateAndLoad();
    }
  }

  /// MANDATORY authentication - must complete before page is accessible
  /// This is called after widget tree is built - NO BYPASS ALLOWED
  Future<void> _authenticateAndLoad() async {
    if (!mounted) return;

    try {
      setState(() {
        _isAuthenticating = true;
        _isAuthenticated = false;
        _authenticationAttempted = false;
      });

      // Small delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      // Check if payment methods are locked due to failed attempts
      final isLocked = await _securityService.isPaymentMethodsLocked();
      if (isLocked) {
        // Show lockout message
        final remainingSeconds = await _securityService
            .getRemainingLockoutSeconds();

        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _isAuthenticated = false;
            _authenticationAttempted = true;
          });

          await _showLockoutDialog(remainingSeconds, 3);
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
        return;
      }

      // Detect available security methods using local_auth
      final availableMethods = await _getAvailableSecurityMethods();
      final pinSet = await _securityService.isPinSet();
      final failedAttempts = await _securityService.getFailedAttempts();
      final remainingAttempts = 3 - failedAttempts;

      // Show blocking dialog that requires user to proceed with authentication
      final shouldAuthenticate = await showDialog<bool>(
        // ignore: use_build_context_synchronously
        context: context,
        barrierDismissible: false, // Cannot dismiss without choosing
        builder: (dialogContext) => PopScope(
          canPop: false, // Prevent back button from closing dialog
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Security Required',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment methods require authentication for security.',
                  style: TextStyle(fontSize: 16),
                ),
                if (failedAttempts > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$remainingAttempts attempt${remainingAttempts != 1 ? 's' : ''} remaining before lockout',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Available authentication methods:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...availableMethods.map(
                  (method) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $method'),
                  ),
                ),
                if (pinSet)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('• Custom PIN'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(Icons.lock_open),
                label: const Text('Continue'),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;

      if (shouldAuthenticate != true) {
        // User cancelled - close page
        setState(() {
          _authenticationAttempted = true;
          _isAuthenticated = false;
          _isAuthenticating = false;
        });
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // User clicked "Continue" - now authenticate
      final authenticated = await _authenticate();

      if (!mounted) return;

      setState(() {
        _authenticationAttempted = true;
      });

      if (authenticated) {
        // Authentication successful - reset failed attempts and allow access
        await _securityService.resetFailedAttempts();
        setState(() {
          _isAuthenticated = true;
          _isAuthenticating = false;
        });
        // Invalidate provider to refresh data
        ref.invalidate(paymentMethodsProvider);
      } else {
        // Authentication failed - increment failed attempts
        await _securityService.incrementFailedAttempts();

        // Check if locked after this failure
        final isLocked = await _securityService.isPaymentMethodsLocked();

        if (isLocked) {
          // System is now locked - show lockout message
          final remainingSeconds = await _securityService
              .getRemainingLockoutSeconds();

          if (mounted) {
            setState(() {
              _isAuthenticated = false;
              _isAuthenticating = false;
            });

            await _showLockoutDialog(remainingSeconds, 3);
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
          return;
        }
        // Authentication failed or was cancelled - IMMEDIATELY close page
        setState(() {
          _isAuthenticated = false;
          _isAuthenticating = false;
        });

        if (mounted) {
          // Get remaining attempts for error message
          final currentFailedAttempts = await _securityService
              .getFailedAttempts();
          final remainingAttempts = 3 - currentFailedAttempts;

          // Show error message with remaining attempts
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      remainingAttempts > 0
                          ? 'Authentication failed. $remainingAttempts attempt${remainingAttempts != 1 ? 's' : ''} remaining.'
                          : 'Authentication failed. Payment methods are now locked.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Force navigation back - user cannot access without authentication
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      debugPrint('Error in authentication flow: $e');
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _isAuthenticated = false;
          _authenticationAttempted = true;
        });
        // Show error and close page
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  /// Get available security methods using local_auth
  Future<List<String>> _getAvailableSecurityMethods() async {
    final methods = <String>[];

    try {
      // Check if device supports biometric authentication
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;

      if (isDeviceSupported || canCheckBiometrics) {
        // Get available biometric types
        final availableBiometrics = await _localAuth.getAvailableBiometrics();

        if (availableBiometrics.isNotEmpty) {
          // Map biometric types to user-friendly names
          for (final biometric in availableBiometrics) {
            switch (biometric) {
              case BiometricType.face:
                if (!methods.contains('Face ID')) {
                  methods.add('Face ID');
                }
                break;
              case BiometricType.fingerprint:
                if (!methods.contains('Fingerprint')) {
                  methods.add('Fingerprint');
                }
                break;
              case BiometricType.iris:
                if (!methods.contains('Iris')) {
                  methods.add('Iris');
                }
                break;
              case BiometricType.strong:
                if (!methods.contains('Strong Biometric')) {
                  methods.add('Strong Biometric');
                }
                break;
              case BiometricType.weak:
                if (!methods.contains('Weak Biometric')) {
                  methods.add('Weak Biometric');
                }
                break;
            }
          }
        }

        // Device PIN/Password is always available if device is supported
        if (!methods.contains('Device PIN / Password')) {
          methods.add('Device PIN / Password');
        }
      }
    } catch (e) {
      debugPrint('Error detecting security methods: $e');
    }

    return methods;
  }

  /// MANDATORY authentication - user MUST authenticate via one of:
  /// 1. Device biometric (Face ID/Touch ID/Fingerprint) - if available
  /// 2. Device PIN/Password - if available
  /// 3. Custom PIN - fallback if biometric/device PIN not available or fails
  /// If custom PIN is not set, user MUST set it up
  /// Returns true ONLY if authentication succeeds - NO BYPASSES ALLOWED
  Future<bool> _authenticate() async {
    if (!mounted) return false;

    // Step 1: Try device security using local_auth
    // Check if device supports authentication
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;

      if (isDeviceSupported || canCheckBiometrics) {
        // Try device security authentication (includes biometric + device PIN/password)
        final deviceAuthSuccess = await _localAuth.authenticate(
          localizedReason: 'Authenticate to access payment methods',
          sensitiveTransaction: true,
          biometricOnly: false, // Allow device PIN/password as fallback
          persistAcrossBackgrounding: true,
        );

        if (deviceAuthSuccess) {
          // Device authentication succeeded - allow access
          debugPrint('Device authentication successful');
          return true;
        }
        // If device auth was cancelled or failed, fallback to custom PIN
        debugPrint(
          'Device authentication failed or cancelled, falling back to custom PIN',
        );
      }
    } catch (e) {
      debugPrint(
        'Device security authentication error: $e, falling back to custom PIN',
      );
      // Continue to PIN fallback - authentication is still required
    }

    // Step 2: FALLBACK to custom PIN - user MUST authenticate
    // Check if PIN is actually set (not just enabled)
    final pinSet = await _securityService.isPinSet();

    if (pinSet) {
      // Check for lockout BEFORE allowing PIN entry
      final isLocked = await _securityService.isPaymentMethodsLocked();
      if (isLocked) {
        // System is locked - don't allow PIN entry
        final remainingSeconds = await _securityService
            .getRemainingLockoutSeconds();
        if (mounted) {
          await _showLockoutDialog(remainingSeconds, 3);
        }
        return false;
      }

      // Get current failed attempts to show status
      final currentFailedAttempts = await _securityService.getFailedAttempts();

      // PIN is set - verify it
      if (!mounted) return false;

      // Show PIN verification - this is REQUIRED, cannot be skipped
      // Pass current failed attempts to show status
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PinSetupPage(
            isSetup: false,
            currentFailedAttempts: currentFailedAttempts,
          ),
          fullscreenDialog: true, // Modal - user must complete it
        ),
      );

      if (!mounted) return false;

      // Only return true if PIN was successfully verified
      if (result == true) {
        return true;
      }

      // PIN verification was cancelled or failed
      // Note: Failed attempts are already incremented in PinSetupPage
      // Check if locked after this failure
      final isNowLocked = await _securityService.isPaymentMethodsLocked();
      if (isNowLocked && mounted) {
        final remainingSeconds = await _securityService
            .getRemainingLockoutSeconds();
        await _showLockoutDialog(remainingSeconds, 3);
      }

      // PIN verification failed - user is NOT allowed
      return false;
    }

    // Step 3: PIN is not set - user MUST set up PIN to proceed
    // This is MANDATORY - cannot access payment methods without security
    if (!mounted) return false;

    final setup = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Cannot dismiss without choosing
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Set Up PIN'),
          ],
        ),
        content: const Text(
          'You must set up a PIN to access payment methods. This is required for security.\n\n'
          'After setting up your PIN, you will need to verify it to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.lock),
            label: const Text('Set Up PIN'),
          ),
        ],
      ),
    );

    if (setup == true) {
      if (!mounted) return false;

      // Set up PIN - this is required
      final setupResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PinSetupPage(isSetup: true),
          fullscreenDialog: true, // Modal - must complete setup
        ),
      );

      if (!mounted) return false;

      if (setupResult == true) {
        // PIN was set up successfully, now MUST authenticate with it immediately
        final verifyResult = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const PinSetupPage(isSetup: false),
            fullscreenDialog: true, // Modal - must verify
          ),
        );

        if (!mounted) return false;

        // Only allow access if PIN was verified
        return verifyResult ?? false;
      }
    }

    // Authentication failed or was cancelled - user is NOT allowed
    // NO BYPASS - must authenticate to access payment methods
    return false;
  }

  /// Show lockout dialog when payment methods are disabled after 3 failed attempts
  Future<void> _showLockoutDialog(
    int remainingSeconds,
    int failedAttempts,
  ) async {
    if (!mounted) return;

    // Calculate time remaining
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

    await showDialog(
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
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePaymentMethod(PaymentMethod method) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: Text('Are you sure you want to delete ${method.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final isOnline = ref.read(isOnlineProvider);
      final repository = ref.read(paymentMethodRepositoryProvider(isOnline));
      await repository.deletePaymentMethod(method.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment method deleted')));
        ref.invalidate(paymentMethodsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting payment method: $e')),
        );
      }
    }
  }

  Future<void> _setDefault(PaymentMethod method) async {
    try {
      final isOnline = ref.read(isOnlineProvider);
      final repository = ref.read(paymentMethodRepositoryProvider(isOnline));
      await repository.setDefaultPaymentMethod(method.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default payment method updated')),
        );
        ref.invalidate(paymentMethodsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error setting default: $e')));
      }
    }
  }

  Future<void> _resetPin() async {
    // First authenticate again
    final authenticated = await _authenticate();
    if (!mounted || !authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication required to reset PIN')),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset PIN'),
        content: const Text(
          'Are you sure you want to reset your PIN? You will need to set a new PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Remove old PIN
    await _securityService.removePin();

    if (!mounted) return;

    // Prompt to set new PIN
    final setupNew = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set New PIN'),
        content: const Text('Please set a new PIN to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );

    if (setupNew == true && mounted) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PinSetupPage(isSetup: true),
        ),
      );

      if (mounted) {
        if (result == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN reset successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'PIN reset cancelled. Please set a PIN to access payment methods.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL SECURITY: Always check lockout status before showing ANY content
    // This prevents bypassing the lockout system
    // ABSOLUTELY NO payment method content should be visible until authenticated AND not locked
    if (_isAuthenticating || !_isAuthenticated) {
      // If authentication was attempted and failed, show error state
      if (_authenticationAttempted && !_isAuthenticated) {
        return PopScope(
          canPop: true, // Allow back navigation after auth failure
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Payment Methods'),
              automaticallyImplyLeading: true,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Authentication Required',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You must authenticate using PIN, Face ID, Biometric, or Device PIN to access payment methods.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Retry authentication
                        _authenticateAndLoad();
                      },
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Show authentication in progress screen
      return PopScope(
        canPop: false, // Prevent back navigation during authentication
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Payment Methods'),
            automaticallyImplyLeading: false, // Prevent back during auth
          ),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Authenticating...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Please authenticate to access payment methods',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'This is required for security',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // CRITICAL SECURITY CHECK: Double-check authentication AND lockout before showing any content
    // This is a final guard to prevent any content from being displayed without authentication
    // Also check lockout status to prevent bypassing the lockout system
    if (!_isAuthenticated || _isAuthenticating) {
      // This should never happen, but if it does, show error and close page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Security Error: Authentication required. Closing page.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      });
      // Return loading screen while closing
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // CRITICAL: Additional lockout check even if authenticated
    // This prevents bypassing lockout by manipulating state or app lifecycle
    // Use FutureBuilder to check lockout status asynchronously on every build
    return FutureBuilder<bool>(
      future: _securityService.isPaymentMethodsLocked(),
      builder: (context, snapshot) {
        // While checking, show loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If locked, show lockout screen and prevent access
        if (snapshot.data == true) {
          // Lock content immediately and show lockout
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              setState(() {
                _isAuthenticated = false;
                _isAuthenticating = false;
              });
              final remainingSeconds = await _securityService
                  .getRemainingLockoutSeconds();
              await _showLockoutDialog(remainingSeconds, 3);
              if (mounted) {
                // ignore: use_build_context_synchronously
                Navigator.maybePop(context);
              }
            }
          });
          return Scaffold(
            appBar: AppBar(title: const Text('Payment Methods')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking security status...'),
                ],
              ),
            ),
          );
        }

        // Not locked and authenticated - show content
        return _buildAuthenticatedContent();
      },
    );
  }

  /// Build the authenticated content (payment methods list)
  Widget _buildAuthenticatedContent() {
    // Only show content if authenticated - FINAL SECURITY CHECK PASSED
    return PopScope(
      canPop: true, // Once authenticated, allow normal back navigation
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment Methods'),
          actions: [
            // Reset PIN option
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.lock_reset, size: 20),
                      SizedBox(width: 8),
                      Text('Reset PIN'),
                    ],
                  ),
                  onTap: () async {
                    // Wait for popup to close
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (!mounted) return;
                    await _resetPin();
                  },
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddPaymentMethodPage(),
                  ),
                );
                if (result == true) {
                  ref.invalidate(paymentMethodsProvider);
                }
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paymentMethodsProvider);
          },
          child: ref
              .watch(paymentMethodsProvider)
              .when(
                data: (paymentMethods) => paymentMethods.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No payment methods',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add a payment method to get started',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AddPaymentMethodPage(),
                                  ),
                                );
                                if (result == true) {
                                  ref.invalidate(paymentMethodsProvider);
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Payment Method'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: paymentMethods.length,
                        itemBuilder: (context, index) {
                          final method = paymentMethods[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(
                                _getPaymentMethodIcon(method.type),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(method.displayName),
                              subtitle:
                                  method.type == PaymentMethodType.card &&
                                      method.expiryMonth != null &&
                                      method.expiryYear != null
                                  ? Text(
                                      'Expires ${method.expiryMonth}/${method.expiryYear}',
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (method.isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Default',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      if (!method.isDefault)
                                        PopupMenuItem(
                                          child: const Text('Set as Default'),
                                          onTap: () => _setDefault(method),
                                        ),
                                      PopupMenuItem(
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onTap: () =>
                                            _deletePaymentMethod(method),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error loading payment methods: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(paymentMethodsProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.card:
        return Icons.credit_card;
      case PaymentMethodType.paypal:
        return Icons.account_balance_wallet;
      case PaymentMethodType.applePay:
        return Icons.apple;
      case PaymentMethodType.googlePay:
        return Icons.account_balance_wallet; // Using wallet icon as fallback
      case PaymentMethodType.wallet:
        return Icons.account_balance_wallet;
    }
  }
}

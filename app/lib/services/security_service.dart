import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';

/// Service for handling biometric and PIN authentication
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'ticketmania_secure',
      preferencesKeyPrefix: 'secure_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accountName: 'ticketmania',
    ),
  );

  static const String _pinKey = 'user_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _pinEnabledKey = 'pin_enabled';
  static const String _failedAttemptsKey = 'payment_auth_failed_attempts';
  static const String _lockoutTimestampKey = 'payment_auth_lockout_timestamp';
  static const int _maxFailedAttempts = 3;
  static const Duration _lockoutDuration = Duration(hours: 1);

  /// Check if biometric authentication is available
  /// Returns true if device supports biometrics or device-level authentication
  Future<bool> isBiometricAvailable() async {
    try {
      // Check if biometric hardware is available
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      // Check if device supports any form of local authentication
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } on LocalAuthException catch (e) {
      debugPrint(
        'LocalAuthException checking biometric availability: ${e.code}',
      );
      return false;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  /// Returns list of enrolled biometric types on the device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics;
    } on LocalAuthException catch (e) {
      debugPrint('LocalAuthException getting available biometrics: ${e.code}');
      return [];
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if biometric authentication is enabled
  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _secureStorage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error reading biometric enabled: $e');
      return false;
    }
  }

  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _biometricEnabledKey,
        value: enabled.toString(),
      );
    } catch (e) {
      debugPrint('Error setting biometric enabled: $e');
    }
  }

  /// Check if PIN is set
  Future<bool> isPinSet() async {
    try {
      final pin = await _secureStorage.read(key: _pinKey);
      return pin != null && pin.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking PIN: $e');
      return false;
    }
  }

  /// Check if PIN authentication is enabled
  Future<bool> isPinEnabled() async {
    try {
      final value = await _secureStorage.read(key: _pinEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error reading PIN enabled: $e');
      return false;
    }
  }

  /// Set PIN
  Future<bool> setPin(String pin) async {
    try {
      if (pin.length < 4) {
        debugPrint('PIN too short: ${pin.length}');
        return false;
      }

      // Write PIN first
      await _secureStorage.write(key: _pinKey, value: pin);
      debugPrint('PIN written to storage');

      // Enable PIN authentication
      await _secureStorage.write(key: _pinEnabledKey, value: 'true');
      debugPrint('PIN enabled flag written to storage');

      // Small delay to ensure writes are committed
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify it was saved correctly
      final savedPin = await _secureStorage.read(key: _pinKey);
      final pinEnabled = await _secureStorage.read(key: _pinEnabledKey);

      debugPrint(
        'Verification - Saved PIN: ${savedPin != null ? "exists" : "null"}, Enabled: $pinEnabled',
      );

      if (savedPin == pin && pinEnabled == 'true') {
        debugPrint('PIN saved and verified successfully');
        return true;
      } else {
        debugPrint(
          'PIN verification failed. Expected: $pin, Got: $savedPin, Enabled: $pinEnabled',
        );
        // Try one more time
        await _secureStorage.write(key: _pinKey, value: pin);
        await _secureStorage.write(key: _pinEnabledKey, value: 'true');
        await Future.delayed(const Duration(milliseconds: 100));
        final retryPin = await _secureStorage.read(key: _pinKey);
        final retryEnabled = await _secureStorage.read(key: _pinEnabledKey);
        if (retryPin == pin && retryEnabled == 'true') {
          debugPrint('PIN saved successfully on retry');
          return true;
        }
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('Error setting PIN: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Verify PIN
  Future<bool> verifyPin(String pin) async {
    try {
      final storedPin = await _secureStorage.read(key: _pinKey);
      return storedPin == pin;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  /// Remove PIN
  Future<void> removePin() async {
    try {
      await _secureStorage.delete(key: _pinKey);
      await _secureStorage.write(key: _pinEnabledKey, value: 'false');
    } catch (e) {
      debugPrint('Error removing PIN: $e');
    }
  }

  /// Authenticate using biometric
  ///
  /// [reason] - The reason shown to the user for authentication
  /// [persistAcrossBackgrounding] - If true, authentication will persist if app is backgrounded
  Future<bool> authenticateWithBiometric({
    String reason = 'Please authenticate to access secure settings',
    bool persistAcrossBackgrounding = true,
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: persistAcrossBackgrounding,
      );

      return authenticated;
    } on LocalAuthException catch (e) {
      debugPrint(
        'LocalAuthException during biometric authentication: ${e.code}',
      );
      // Handle specific error codes if needed
      if (e.code == LocalAuthExceptionCode.noBiometricHardware) {
        debugPrint('Biometric authentication not available - no hardware');
      } else if (e.code == LocalAuthExceptionCode.temporaryLockout ||
          e.code == LocalAuthExceptionCode.biometricLockout) {
        debugPrint('Biometric authentication temporarily locked');
      }
      return false;
    } catch (e) {
      debugPrint('Error authenticating with biometric: $e');
      return false;
    }
  }

  /// Authenticate using PIN
  Future<bool> authenticateWithPin(String pin) async {
    try {
      final isEnabled = await isPinEnabled();
      if (!isEnabled) {
        return false;
      }
      return await verifyPin(pin);
    } catch (e) {
      debugPrint('Error authenticating with PIN: $e');
      return false;
    }
  }

  /// Authenticate using available method (device security first, then custom PIN)
  Future<bool> authenticate({
    String reason = 'Please authenticate to access secure settings',
    bool persistAcrossBackgrounding = true,
  }) async {
    try {
      // First, try device security (biometric/Face ID/Touch ID)
      final biometricAvailable = await isBiometricAvailable();

      if (biometricAvailable) {
        // Try to authenticate with device security
        // Note: We don't check isBiometricEnabled() here because we want to use
        // device security if available, regardless of app settings
        try {
          final authenticated = await _localAuth.authenticate(
            localizedReason: reason,
            biometricOnly: false, // Allow device PIN/password as fallback
            persistAcrossBackgrounding: persistAcrossBackgrounding,
          );
          if (authenticated) {
            return true;
          }
        } on LocalAuthException catch (e) {
          debugPrint(
            'LocalAuthException during device security authentication: ${e.code}',
          );
          // Handle specific error codes
          if (e.code == LocalAuthExceptionCode.temporaryLockout ||
              e.code == LocalAuthExceptionCode.biometricLockout) {
            debugPrint('Authentication temporarily locked');
          } else {
            debugPrint('Authentication failed or canceled: ${e.code}');
          }
          // Fall through to custom PIN
        } catch (e) {
          debugPrint('Device security authentication failed: $e');
          // Fall through to custom PIN
        }
      }

      // Fallback to custom PIN if device security is not available or fails
      final pinEnabled = await isPinEnabled();
      if (pinEnabled) {
        // PIN verification should be handled by the UI
        // This method just checks if authentication is possible
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error authenticating: $e');
      return false;
    }
  }

  /// Get platform-specific biometric name
  String getBiometricName(List<BiometricType> types) {
    if (types.isEmpty) {
      return 'Biometric';
    }

    if (Platform.isIOS) {
      if (types.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (types.contains(BiometricType.fingerprint)) {
        return 'Touch ID';
      }
    } else if (Platform.isAndroid) {
      if (types.contains(BiometricType.face)) {
        return 'Face Unlock';
      } else if (types.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (types.contains(BiometricType.strong)) {
        return 'Biometric';
      }
    }

    return 'Biometric';
  }

  /// Get failed authentication attempts for payment methods
  Future<int> getFailedAttempts() async {
    try {
      final attempts = await _secureStorage.read(key: _failedAttemptsKey);
      return attempts != null ? int.tryParse(attempts) ?? 0 : 0;
    } catch (e) {
      debugPrint('Error reading failed attempts: $e');
      return 0;
    }
  }

  /// Increment failed authentication attempts
  Future<void> incrementFailedAttempts() async {
    try {
      final currentAttempts = await getFailedAttempts();
      final newAttempts = currentAttempts + 1;
      await _secureStorage.write(
        key: _failedAttemptsKey,
        value: newAttempts.toString(),
      );

      // If reached max attempts, set lockout timestamp
      if (newAttempts >= _maxFailedAttempts) {
        await _secureStorage.write(
          key: _lockoutTimestampKey,
          value: DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }
    } catch (e) {
      debugPrint('Error incrementing failed attempts: $e');
    }
  }

  /// Reset failed authentication attempts (call on successful authentication)
  Future<void> resetFailedAttempts() async {
    try {
      await _secureStorage.delete(key: _failedAttemptsKey);
      await _secureStorage.delete(key: _lockoutTimestampKey);
    } catch (e) {
      debugPrint('Error resetting failed attempts: $e');
    }
  }

  /// Check if payment methods are locked due to failed attempts
  Future<bool> isPaymentMethodsLocked() async {
    try {
      final lockoutTimestamp = await _secureStorage.read(
        key: _lockoutTimestampKey,
      );
      if (lockoutTimestamp == null) {
        return false; // Not locked
      }

      final lockoutTime = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(lockoutTimestamp) ?? 0,
      );
      final now = DateTime.now();
      final elapsed = now.difference(lockoutTime);

      // If lockout period has passed, reset and unlock
      if (elapsed >= _lockoutDuration) {
        await resetFailedAttempts();
        return false;
      }

      return true; // Still locked
    } catch (e) {
      debugPrint('Error checking lockout status: $e');
      return false;
    }
  }

  /// Get remaining lockout time in seconds
  Future<int> getRemainingLockoutSeconds() async {
    try {
      final lockoutTimestamp = await _secureStorage.read(
        key: _lockoutTimestampKey,
      );
      if (lockoutTimestamp == null) {
        return 0;
      }

      final lockoutTime = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(lockoutTimestamp) ?? 0,
      );
      final now = DateTime.now();
      final elapsed = now.difference(lockoutTime);
      final remaining = _lockoutDuration - elapsed;

      return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
    } catch (e) {
      debugPrint('Error getting remaining lockout time: $e');
      return 0;
    }
  }

  /// Get failed attempts count
  Future<int> getFailedAttemptsCount() async {
    return await getFailedAttempts();
  }
}

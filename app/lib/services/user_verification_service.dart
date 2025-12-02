import 'package:flutter/foundation.dart';
import '../main.dart';

/// Service to verify user existence in the database
class UserVerificationService {
  /// Check if the current user exists in the profiles table
  /// Returns true if user exists, false if not found or error
  Future<bool> verifyUserExists() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('UserVerificationService: No current user');
        return false;
      }

      // Check if user exists in profiles table
      final response = await supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        debugPrint('UserVerificationService: User not found in profiles table');
        return false;
      }

      debugPrint('UserVerificationService: User verified in database');
      return true;
    } catch (e) {
      debugPrint('UserVerificationService: Error verifying user: $e');
      // If there's an error (e.g., network issue), assume user exists
      // to avoid logging out on temporary network problems
      return true;
    }
  }

  /// Verify user and log out if not found
  /// Returns true if user exists, false if logged out
  Future<bool> verifyAndLogoutIfNeeded() async {
    final exists = await verifyUserExists();
    if (!exists) {
      debugPrint('UserVerificationService: User not found, logging out...');
      try {
        await supabase.auth.signOut();
        debugPrint('UserVerificationService: User logged out successfully');
      } catch (e) {
        debugPrint('UserVerificationService: Error logging out: $e');
      }
      return false;
    }
    return true;
  }
}

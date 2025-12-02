import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

/// Centralized error handler that converts technical errors to user-friendly messages
class ErrorHandler {
  /// Get a user-friendly error message from any error
  static String getUserFriendlyMessage(dynamic error, {String? context}) {
    if (error == null) {
      return _getGenericErrorMessage(context);
    }

    final errorString = error.toString().toLowerCase();

    // Check for network/connection errors
    if (error is SocketException || 
        errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('internet') ||
        errorString.contains('timed out') ||
        errorString.contains('timeout')) {
      return 'Failed to connect to server. Please check your internet connection.';
    }

    // Check for authentication errors
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      
      if (message.contains('invalid') && message.contains('credentials')) {
        return 'Invalid email or password. Please try again.';
      }
      if (message.contains('email') && message.contains('not confirmed')) {
        return 'Please check your email to confirm your account.';
      }
      if (message.contains('email') && message.contains('already')) {
        return 'An account with this email already exists.';
      }
      if (message.contains('password')) {
        return 'Password is incorrect. Please try again.';
      }
      if (message.contains('token') || message.contains('session')) {
        return 'Your session has expired. Please sign in again.';
      }
      if (message.contains('too many requests')) {
        return 'Too many attempts. Please try again later.';
      }
    }

    // Check for Supabase/postgres errors
    if (errorString.contains('postgres') || 
        errorString.contains('database') ||
        errorString.contains('sql')) {
      return 'Failed to connect to server. Please try again later.';
    }

    // Check for permission errors
    if (errorString.contains('permission') || 
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return 'You do not have permission to perform this action.';
    }

    // Check for not found errors
    if (errorString.contains('not found') || 
        errorString.contains('404') ||
        errorString.contains('does not exist')) {
      if (context != null) {
        return 'Failed to find $context. Please try again.';
      }
      return 'Requested item not found. Please try again.';
    }

    // Context-specific error messages
    if (context != null) {
      if (context.contains('book') || context.contains('ticket')) {
        return 'Failed to book ticket. Please try again.';
      }
      if (context.contains('load') || context.contains('fetch')) {
        return 'Failed to load data. Please try again.';
      }
      if (context.contains('save') || context.contains('update')) {
        return 'Failed to save changes. Please try again.';
      }
      if (context.contains('delete')) {
        return 'Failed to delete. Please try again.';
      }
      if (context.contains('sign in') || context.contains('login')) {
        return 'Failed to sign in. Please check your credentials and try again.';
      }
      if (context.contains('sign up') || context.contains('register')) {
        return 'Failed to create account. Please try again.';
      }
      if (context.contains('payment')) {
        return 'Failed to process payment. Please try again.';
      }
      if (context.contains('wallet')) {
        return 'Failed to update wallet. Please try again.';
      }
      if (context.contains('profile')) {
        return 'Failed to update profile. Please try again.';
      }
      if (context.contains('validate') || context.contains('validation')) {
        return 'Failed to validate ticket. Please try again.';
      }
      return 'Failed to $context. Please try again.';
    }

    // Generic fallback
    return _getGenericErrorMessage(context);
  }

  /// Get a generic error message
  static String _getGenericErrorMessage(String? context) {
    if (context != null) {
      return 'Failed to $context. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Show a user-friendly error snackbar
  static void showError(BuildContext context, dynamic error, {String? contextMessage}) {
    if (!context.mounted) return;
    
    final message = getUserFriendlyMessage(error, context: contextMessage);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show a success snackbar
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00BF63),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show an info snackbar
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Check if error is a network error
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    final errorString = error.toString().toLowerCase();
    
    return error is SocketException ||
        errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('internet') ||
        errorString.contains('timed out') ||
        errorString.contains('timeout');
  }
}


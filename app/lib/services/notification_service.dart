import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == false) {
        debugPrint('Notification service initialization returned false');
        return;
      }

      // Create notification channel for Android (required for Android 8.0+)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        if (androidImplementation != null) {
          // Create notification channel first (required before requesting permission)
          const androidChannel = AndroidNotificationChannel(
            'ticketmania_channel',
            'Ticket Mania Notifications',
            description: 'Notifications for ticket bookings and updates',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );

          await androidImplementation.createNotificationChannel(androidChannel);
          debugPrint('Notification channel created: ticketmania_channel');

          // Request POST_NOTIFICATIONS permission for Android 13+ (API 33+)
          final granted = await androidImplementation
              .requestNotificationsPermission();
          if (granted == true) {
            debugPrint('Notification permission granted');
          } else {
            debugPrint('Notification permission denied or not available');
          }
        }
      }

      _initialized = true;
      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
      // Don't set _initialized to true if initialization failed
      // This allows retry on next call
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // You can add navigation logic here based on payload
  }

  /// Show a simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
      // If still not initialized after retry, skip showing notification
      if (!_initialized) {
        debugPrint('Cannot show notification: service not initialized');
        return;
      }
    }

    // Check permission before showing notification (Android 13+)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final hasPermission = await hasNotificationPermission();
      if (!hasPermission) {
        debugPrint('Notification permission not granted, requesting...');
        final granted = await requestPermission();
        if (!granted) {
          debugPrint('Cannot show notification: permission denied');
          return;
        }
      }
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'ticketmania_channel',
        'Ticket Mania Notifications',
        channelDescription: 'Notifications for ticket bookings and updates',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      debugPrint('Notification shown: $title - $body');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Check if booking notifications are enabled
  Future<bool> _isBookingNotificationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notification_booking') ?? true; // Default to true
    } catch (e) {
      debugPrint('Error checking notification preference: $e');
      return true; // Default to enabled if error
    }
  }

  /// Show a notification for successful ticket booking
  Future<void> showBookingSuccessNotification({
    required String ticketTypeName,
    required double price,
    required int quantity,
    String? bookingId,
  }) async {
    // Check if booking notifications are enabled
    final isEnabled = await _isBookingNotificationEnabled();
    if (!isEnabled) {
      debugPrint('Booking notifications are disabled in settings');
      return;
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Ticket Booked Successfully! 🎉',
      body:
          '${quantity}x $ticketTypeName for €${(price * quantity).toStringAsFixed(2)}',
      payload: bookingId,
    );
  }

  /// Check if expiration notifications are enabled
  Future<bool> _isExpirationNotificationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notification_expiration') ??
          true; // Default to true
    } catch (e) {
      debugPrint('Error checking notification preference: $e');
      return true; // Default to enabled if error
    }
  }

  /// Show a notification for ticket expiration warning
  Future<void> showExpirationWarningNotification({
    required String ticketTypeName,
    required DateTime expiresAt,
    String? bookingId,
  }) async {
    // Check if expiration notifications are enabled
    final isEnabled = await _isExpirationNotificationEnabled();
    if (!isEnabled) {
      debugPrint('Expiration notifications are disabled in settings');
      return;
    }

    final hoursUntilExpiry = expiresAt.difference(DateTime.now()).inHours;
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 1,
      title: 'Ticket Expiring Soon ⏰',
      body: '$ticketTypeName expires in $hoursUntilExpiry hours',
      payload: bookingId,
    );
  }

  /// Check if low balance notifications are enabled
  Future<bool> _isLowBalanceNotificationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notification_low_balance') ??
          true; // Default to true
    } catch (e) {
      debugPrint('Error checking notification preference: $e');
      return true; // Default to enabled if error
    }
  }

  /// Show a notification for low wallet balance
  Future<void> showLowBalanceNotification({required double balance}) async {
    // Check if low balance notifications are enabled
    final isEnabled = await _isLowBalanceNotificationEnabled();
    if (!isEnabled) {
      debugPrint('Low balance notifications are disabled in settings');
      return;
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 2,
      title: 'Low Wallet Balance 💰',
      body:
          'Your wallet balance is €${balance.toStringAsFixed(2)}. Consider adding more funds.',
    );
  }

  /// Check if favorite reminder notifications are enabled
  Future<bool> _isFavoriteReminderEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notification_favorite_reminders') ??
          false; // Default to false
    } catch (e) {
      debugPrint('Error checking notification preference: $e');
      return false; // Default to disabled if error
    }
  }

  /// Show a notification for favorite ticket reminder
  Future<void> showFavoriteReminderNotification({
    required String ticketTypeName,
    String? favoriteId,
  }) async {
    // Check if favorite reminder notifications are enabled
    final isEnabled = await _isFavoriteReminderEnabled();
    if (!isEnabled) {
      debugPrint('Favorite reminder notifications are disabled in settings');
      return;
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 3,
      title: 'Quick Book Favorite 🚀',
      body: 'Tap to quickly book your favorite: $ticketTypeName',
      payload: favoriteId,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Test notification - for debugging
  Future<void> testNotification() async {
    await showNotification(
      id: 999999,
      title: 'Test Notification',
      body: 'If you see this, notifications are working!',
    );
  }

  /// Get initialization status
  bool get isInitialized => _initialized;

  /// Check if notification permission is granted
  Future<bool> hasNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final granted = await androidImplementation.areNotificationsEnabled();
        return granted ?? false;
      }
    }
    // For iOS, assume granted if initialized
    return _initialized;
  }

  /// Request notification permission explicitly
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final granted = await androidImplementation
            .requestNotificationsPermission();
        return granted ?? false;
      }
    }
    return false;
  }

  /// Schedule a notification for a specific time (Android only)
  /// Note: For iOS, use showNotification with a delay instead
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // For now, we'll use a simple delay-based approach
    // For production, consider adding timezone package for proper scheduling
    final delay = scheduledDate.difference(DateTime.now());
    if (delay.isNegative) {
      debugPrint('Cannot schedule notification in the past');
      return;
    }

    // Use Future.delayed for cross-platform compatibility
    Future.delayed(delay, () {
      showNotification(id: id, title: title, body: body, payload: payload);
    });
  }
}

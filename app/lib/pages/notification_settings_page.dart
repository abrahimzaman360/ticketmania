import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _bookingNotifications = true;
  bool _expirationWarnings = true;
  bool _lowBalanceAlerts = true;
  bool _favoriteReminders = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _bookingNotifications =
            prefs.getBool('notification_booking') ?? true;
        _expirationWarnings = prefs.getBool('notification_expiration') ?? true;
        _lowBalanceAlerts = prefs.getBool('notification_low_balance') ?? true;
        _favoriteReminders =
            prefs.getBool('notification_favorite_reminders') ?? false;
      });
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Error saving notification setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notification Settings'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Booking Notifications'),
                  subtitle: const Text(
                    'Get notified when tickets are successfully booked',
                  ),
                  value: _bookingNotifications,
                  onChanged: (value) {
                    setState(() => _bookingNotifications = value);
                    _saveSetting('notification_booking', value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Expiration Warnings'),
                  subtitle: const Text(
                    'Get notified when your tickets are about to expire',
                  ),
                  value: _expirationWarnings,
                  onChanged: (value) {
                    setState(() => _expirationWarnings = value);
                    _saveSetting('notification_expiration', value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Low Balance Alerts'),
                  subtitle: const Text(
                    'Get notified when your wallet balance is low',
                  ),
                  value: _lowBalanceAlerts,
                  onChanged: (value) {
                    setState(() => _lowBalanceAlerts = value);
                    _saveSetting('notification_low_balance', value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Favorite Reminders'),
                  subtitle: const Text(
                    'Get reminders about your favorite ticket routes',
                  ),
                  value: _favoriteReminders,
                  onChanged: (value) {
                    setState(() => _favoriteReminders = value);
                    _saveSetting('notification_favorite_reminders', value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Test Notification Button
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('Test Notification'),
              subtitle: const Text('Send a test notification to verify setup'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final notificationService = NotificationService();
                
                // Ensure service is initialized
                if (!notificationService.isInitialized) {
                  await notificationService.initialize();
                }
                
                // Check and request permission if needed
                final hasPermission = await notificationService.hasNotificationPermission();
                if (!hasPermission) {
                  final granted = await notificationService.requestPermission();
                  if (!granted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification permission is required. Please enable it in app settings.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                }
                
                // Send test notification
                await notificationService.testNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification sent! Check your notification tray.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Note: Make sure notifications are enabled in your device settings for these preferences to work. Use the test button above to verify notifications are working.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}


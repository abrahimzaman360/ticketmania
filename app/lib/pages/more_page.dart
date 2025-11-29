import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/ble_service.dart';
import 'profile_page.dart';
import 'language_page.dart';
import 'notification_settings_page.dart';
import 'permissions_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.signOut),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.signOut),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadUserProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? {};
          final userName = profile['full_name'] as String? ?? 
                          user?.email?.split('@').first ?? 'User';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? 'User',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),

              // Settings Section
          Text(
            'Settings',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                Consumer<BLEService>(
                  builder: (context, bleService, _) {
                    // Use cached value for immediate UI update, load async for first time
                    final isEnabled = bleService.autoValidationEnabled;
                    return ListTile(
                      leading: Icon(
                        isEnabled
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: isEnabled 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey,
                      ),
                      title: Text(AppLocalizations.of(context)!.autoValidationBLE),
                      subtitle: Text(
                        isEnabled
                            ? AppLocalizations.of(context)!.activeTicketsAutoValidate
                            : AppLocalizations.of(context)!.inactiveEnableAutoValidate,
                      ),
                      trailing: Switch(
                        value: isEnabled,
                            onChanged: (value) async {
                              if (value) {
                                // Save preference first
                                await bleService.setAutoValidationEnabled(true);
                                
                                // Show loading indicator
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                
                                final initialized = await bleService.initialize();
                                
                                if (context.mounted) {
                                  Navigator.of(context).pop(); // Close loading dialog
                                }
                                
                                if (initialized) {
                                  await bleService.startAdvertising();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(AppLocalizations.of(context)!.bleAutoValidationEnabled),
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                      ),
                                    );
                                  }
                                } else {
                                  // If initialization failed, revert preference
                                  await bleService.setAutoValidationEnabled(false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)!.pleaseEnableBluetooth,
                                        ),
                                        backgroundColor: Colors.orange,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                // Save preference and stop advertising
                                await bleService.setAutoValidationEnabled(false);
                                await bleService.stopAdvertising();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(AppLocalizations.of(context)!.bleAutoValidationDisabled),
                                      backgroundColor: Colors.grey,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(AppLocalizations.of(context)!.profile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(AppLocalizations.of(context)!.notifications),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationSettingsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(AppLocalizations.of(context)!.language),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LanguagePage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Permissions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PermissionsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About Section
          Text(
            'About',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(AppLocalizations.of(context)!.aboutTicketMania),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: AppLocalizations.of(context)!.appTitle,
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.confirmation_number, size: 48),
                      children: [
                        const Text('EU Public Transport Ticket Booking Service'),
                        const SizedBox(height: 16),
                        const Text(
                          'Solo Software Engineered by Ibrahim Zaman',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final url = Uri.parse(
                                  'https://github.com/abrahimzaman360',
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.code),
                              label: const Text('GitHub'),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final url = Uri.parse(
                                  'https://linkedin.com/in/abrahimzaman360',
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.business),
                              label: const Text('LinkedIn'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(AppLocalizations.of(context)!.privacyPolicy),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Privacy policy coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(AppLocalizations.of(context)!.termsOfService),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Terms of service coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

              // Account Actions
          Text(
            'Account',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.orange),
                  title: Text(AppLocalizations.of(context)!.signOut),
                  onTap: () => _signOut(context),
                ),
              ],
            ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return {};

      final response = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      return response ?? {};
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return {};
    }
  }
}


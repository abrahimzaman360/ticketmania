import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/l10n/app_localizations.dart';
import '../main.dart';
import '../services/ble_service.dart';
import 'profile_page.dart';
import 'language_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteAccount),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone and will permanently delete all your data including bookings, wallet, and transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(AppLocalizations.of(context)!.deleteAccount),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Delete user data from database tables
      // RLS policies now allow users to delete their own data
      
      // Get wallet first to delete transactions
      final walletResponse = await supabase
          .from('wallets')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (walletResponse != null) {
        // Delete wallet transactions
        await supabase
            .from('wallet_transactions')
            .delete()
            .eq('wallet_id', walletResponse['id']);
        
        // Delete wallet
        await supabase
            .from('wallets')
            .delete()
            .eq('user_id', userId);
      }
      
      // Delete bookings (cascade will handle validation_logs)
      await supabase
          .from('bookings')
          .delete()
          .eq('user_id', userId);
      
      // Delete payments
      await supabase
          .from('payments')
          .delete()
          .eq('user_id', userId);
      
      // Delete profile
      await supabase
          .from('profiles')
          .delete()
          .eq('id', userId);

      // Sign out (this will remove the auth session)
      await supabase.auth.signOut();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.accountDeletedSuccessfully),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.failedToDeleteAccount}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
      body: ListView(
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
                          user?.email?.substring(0, 1).toUpperCase() ?? 'U',
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
                              user?.email ?? 'User',
                              style: Theme.of(context).textTheme.titleMedium,
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
                    return ListTile(
                      leading: Icon(
                        bleService.isAdvertising
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: bleService.isAdvertising 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey,
                      ),
                      title: Text(AppLocalizations.of(context)!.autoValidationBLE),
                      subtitle: Text(
                        bleService.isAdvertising
                            ? AppLocalizations.of(context)!.activeTicketsAutoValidate
                            : AppLocalizations.of(context)!.inactiveEnableAutoValidate,
                      ),
                      trailing: Switch(
                        value: bleService.isAdvertising,
                        onChanged: (value) async {
                          if (value) {
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Notifications settings coming soon')),
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
                        Text('EU Public Transport Ticket Booking Service'),
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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(
                    AppLocalizations.of(context)!.deleteAccount,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


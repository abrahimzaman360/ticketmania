import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../providers/ble_provider.dart';
import '../providers/booking_providers.dart';
import '../providers/payment_method_providers.dart';
import 'profile_page.dart';
import 'language_page.dart';
import 'notification_settings_page.dart';
import 'permissions_page.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _MorePageContent(ref: ref);
  }
}

class _MorePageContent extends ConsumerWidget {
  const _MorePageContent({required this.ref});

  final WidgetRef ref;

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.signOut),
        content: const Text('Are you sure you want to sign out?'),
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

    if (confirm == true && context.mounted) {
      // Show loading dialog using root navigator to ensure it can be closed after navigation
      if (!context.mounted) return;

      // Use root navigator context to ensure dialog can be dismissed even after navigation
      final rootNavigator = Navigator.of(context, rootNavigator: true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false, // Prevent closing by back button
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Signing out...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      try {
        // Invalidate all providers to reset state
        ref.invalidate(activeBookingsProvider);
        ref.invalidate(allBookingsProvider);
        ref.invalidate(paymentMethodsProvider);

        // Add minimum loading time to ensure user sees the loading state
        // This creates a smooth user experience
        await Future.delayed(const Duration(milliseconds: 600));

        // Close loading dialog BEFORE sign out to prevent it from showing over auth page
        // This ensures the dialog is closed before navigation happens
        if (rootNavigator.canPop()) {
          rootNavigator.pop(); // Close loading dialog
        }

        // Small delay to ensure dialog is fully closed before sign out
        await Future.delayed(const Duration(milliseconds: 100));

        // Sign out from Supabase (this will trigger auth state change and navigation)
        await supabase.auth.signOut();

        // Show success snackbar - use post-frame callback to ensure context is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
            if (scaffoldMessenger != null) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Signed out successfully'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          } catch (e) {
            // Ignore if context is no longer available
            debugPrint('Could not show snackbar: $e');
          }
        });
        // Navigation to sign in page will happen automatically via StreamBuilder in main.dart
      } catch (error) {
        // Close loading dialog on error using root navigator
        if (rootNavigator.canPop()) {
          rootNavigator.pop(); // Close loading dialog
        }

        // Show error snackbar
        try {
          // ignore: use_build_context_synchronously
          final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
          if (scaffoldMessenger != null) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Error signing out: $error'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          debugPrint('Could not show error snackbar: $e');
        }
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // App Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.confirmation_number,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // App Name
                    Text(
                      AppLocalizations.of(context)!.appTitle,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Version
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Developer Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Engineered by',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ibrahim Zaman',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Social Links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // GitHub
                        _SocialButton(
                          icon: Icons.code,
                          label: 'GitHub',
                          color: Colors.grey[800]!,
                          onTap: () async {
                            final url = Uri.parse(
                              'https://github.com/abrahimzaman360',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        // LinkedIn
                        _SocialButton(
                          icon: Icons.business,
                          label: 'LinkedIn',
                          color: const Color(0xFF0077B5),
                          onTap: () async {
                            final url = Uri.parse(
                              'https://linkedin.com/in/abrahimzaman360',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadUserProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? {};
          final userName =
              profile['full_name'] as String? ??
              user?.email?.split('@').first ??
              'User';

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
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : user?.email
                                            ?.substring(0, 1)
                                            .toUpperCase() ??
                                        'U',
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
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? 'User',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[600]),
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
                    Consumer(
                      builder: (context, ref, _) {
                        final bleService = ref.watch(bleServiceProvider);
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
                          title: Text(
                            AppLocalizations.of(context)!.autoValidationBLE,
                          ),
                          subtitle: Text(
                            isEnabled
                                ? AppLocalizations.of(
                                    context,
                                  )!.activeTicketsAutoValidate
                                : AppLocalizations.of(
                                    context,
                                  )!.inactiveEnableAutoValidate,
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

                                final initialized = await bleService
                                    .initialize();

                                if (context.mounted) {
                                  Navigator.of(
                                    context,
                                  ).pop(); // Close loading dialog
                                }

                                if (initialized) {
                                  await bleService.startAdvertising();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.bleAutoValidationEnabled,
                                        ),
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    );
                                  }
                                } else {
                                  // If initialization failed, revert preference
                                  await bleService.setAutoValidationEnabled(
                                    false,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.pleaseEnableBluetooth,
                                        ),
                                        backgroundColor: Colors.orange,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                // Save preference and stop advertising
                                await bleService.setAutoValidationEnabled(
                                  false,
                                );
                                await bleService.stopAdvertising();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.bleAutoValidationDisabled,
                                      ),
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
                            builder: (context) =>
                                const NotificationSettingsPage(),
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
                      title: Text(
                        AppLocalizations.of(context)!.aboutTicketMania,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAboutDialog(context),
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
                          SnackBar(
                            content: Text('Terms of service coming soon'),
                          ),
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

// Social Button Widget
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

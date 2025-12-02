import 'package:flutter/material.dart';
import '../main.dart';
import '../services/security_service.dart';
import '../pages/payment_methods_page.dart';
import '../pages/pin_setup_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final SecurityService _securityService = SecurityService();
  bool _isLoading = false;
  bool _isSaving = false;

  // Track initial values to detect changes
  String _initialName = '';
  String _initialPhone = '';
  String _initialAddress = '';

  /// Check if any field has been modified
  bool get _hasChanges {
    return _nameController.text.trim() != _initialName ||
        _phoneController.text.trim() != _initialPhone ||
        _addressController.text.trim() != _initialAddress;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<bool> _authenticateForPaymentMethods() async {
    // First, try device security (Face ID/Touch ID/Fingerprint/Device PIN)
    final biometricAvailable = await _securityService.isBiometricAvailable();

    if (biometricAvailable) {
      // Try device security authentication
      final authenticated = await _securityService.authenticate(
        reason: 'Authenticate to access payment methods',
      );
      if (authenticated) {
        return true;
      }
      // If device security fails, fall through to custom PIN
    }

    // Fallback to custom PIN if device security is not available or fails
    final pinEnabled = await _securityService.isPinEnabled();
    if (pinEnabled) {
      if (!mounted) return false;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PinSetupPage(isSetup: false),
        ),
      );
      return result ?? false;
    }

    // If no security is set up, prompt to set up PIN
    if (!mounted) return false;
    final setup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Required'),
        content: const Text(
          'You need to set up a PIN to access payment methods. Would you like to set one up now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set Up PIN'),
          ),
        ],
      ),
    );

    if (setup == true) {
      if (!mounted) return false;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PinSetupPage(isSetup: true),
        ),
      );
      if (result == true) {
        return true;
      }
    }

    return false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Load profile data
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        _nameController.text = response['full_name'] as String? ?? '';
        // Try different possible column names for phone
        _phoneController.text =
            (response['phone_number'] as String? ??
            response['phone'] as String? ??
            '');
        // Try different possible column names for address
        _addressController.text = response['address'] as String? ?? '';

        // Store initial values to track changes
        _initialName = _nameController.text.trim();
        _initialPhone = _phoneController.text.trim();
        _initialAddress = _addressController.text.trim();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      final profileData = <String, dynamic>{
        'id': user.id,
        'full_name': _nameController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Only include phone if it's not empty - try different column names
      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty) {
        // Try phone_number first (common naming), fallback to phone
        profileData['phone_number'] = phone;
      }

      // Only include address if it's not empty
      final address = _addressController.text.trim();
      if (address.isNotEmpty) {
        profileData['address'] = address;
      }

      // Upsert profile - handle missing columns gracefully
      try {
        await supabase.from('profiles').upsert(profileData);
      } catch (e) {
        final errorStr = e.toString().toLowerCase();

        // If phone_number column doesn't exist, try phone or remove it
        if (phone.isNotEmpty &&
            (errorStr.contains('phone_number') || errorStr.contains('phone'))) {
          profileData.remove('phone_number');
          profileData.remove('phone');
          // Try with phone column name
          try {
            profileData['phone'] = phone;
            await supabase.from('profiles').upsert(profileData);
          } catch (_) {
            // If phone also fails, remove it and continue with just full_name
            profileData.remove('phone');
            await supabase.from('profiles').upsert(profileData);
          }
        }
        // If address column doesn't exist, remove it and try again
        else if (address.isNotEmpty && errorStr.contains('address')) {
          profileData.remove('address');
          await supabase.from('profiles').upsert(profileData);
        }
        // If full_name fails, that's a critical error
        else if (errorStr.contains('full_name')) {
          rethrow;
        }
        // For any other error, try with minimal data (just id and full_name)
        else {
          final minimalData = {
            'id': user.id,
            'full_name': _nameController.text.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          await supabase.from('profiles').upsert(minimalData);

          // Show warning that some fields couldn't be saved
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Profile saved, but some fields may not be supported',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (mounted) {
        // Update initial values to reflect saved state
        _initialName = _nameController.text.trim();
        _initialPhone = _phoneController.text.trim();
        _initialAddress = _addressController.text.trim();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        setState(() {}); // Update UI to reflect no changes
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: (_isSaving || !_hasChanges) ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: _hasChanges
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture Section
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0].toUpperCase()
                                  : user?.email
                                            ?.substring(0, 1)
                                            .toUpperCase() ??
                                        'U',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user?.email ?? 'User',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Personal Information
                    Text(
                      'Personal Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                      onChanged: (_) =>
                          setState(() {}), // Update avatar and save button
                    ),
                    const SizedBox(height: 16),

                    // Phone - Disabled
                    TextFormField(
                      controller: _phoneController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Phone number is disabled',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 32),

                    // Account Information
                    Text(
                      'Account Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.email_outlined),
                            title: const Text('Email'),
                            subtitle: Text(user?.email ?? 'Not available'),
                            trailing: const Icon(Icons.lock_outline, size: 20),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: const Text('Member Since'),
                            subtitle: Text(
                              user?.createdAt != null
                                  ? () {
                                      try {
                                        final createdAt = user?.createdAt;
                                        if (createdAt != null) {
                                          final date = DateTime.parse(
                                            createdAt,
                                          );
                                          return '${date.day}/${date.month}/${date.year}';
                                        }
                                        return 'Not available';
                                      } catch (e) {
                                        return 'Not available';
                                      }
                                    }()
                                  : 'Not available',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Payment Methods Section
                    Text(
                      'Payment Methods',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.payment),
                        title: const Text('Payment Methods'),
                        subtitle: const Text('Manage your payment methods'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          if (!await _authenticateForPaymentMethods()) return;
                          if (!mounted) return;

                          Navigator.push(
                            // ignore: use_build_context_synchronously
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaymentMethodsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Delete Account Section
                    Text(
                      'Danger Zone',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        leading: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'Permanently delete your account and all data',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: () => _deleteAccount(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and will permanently delete all your data including bookings, wallet, and transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
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
        builder: (context) => const Center(child: CircularProgressIndicator()),
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
        await supabase.from('wallets').delete().eq('user_id', userId);
      }

      // Delete bookings (cascade will handle validation_logs)
      await supabase.from('bookings').delete().eq('user_id', userId);

      // Delete payments
      await supabase.from('payments').delete().eq('user_id', userId);

      // Delete profile
      await supabase.from('profiles').delete().eq('id', userId);

      // Sign out (this will remove the auth session)
      await supabase.auth.signOut();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account deleted successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

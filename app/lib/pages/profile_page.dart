import 'package:flutter/material.dart';
import '../main.dart';

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
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
        _phoneController.text = (response['phone_number'] as String? ?? 
                                 response['phone'] as String? ?? '');
        // Try different possible column names for address
        _addressController.text = response['address'] as String? ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
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
        if (phone.isNotEmpty && (errorStr.contains('phone_number') || errorStr.contains('phone'))) {
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
                content: const Text('Profile saved, but some fields may not be supported'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
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
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
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
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0].toUpperCase()
                                  : user?.email?.substring(0, 1).toUpperCase() ?? 'U',
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
                      onChanged: (_) => setState(() {}), // Update avatar
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter your phone number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          // Basic phone validation
                          final phoneRegex = RegExp(r'^[+]?[(]?[0-9]{1,4}[)]?[-\s.]?[(]?[0-9]{1,4}[)]?[-\s.]?[0-9]{1,9}$');
                          if (!phoneRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid phone number';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        hintText: 'Enter your address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.words,
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
                                          final date = DateTime.parse(createdAt);
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
                  ],
                ),
              ),
            ),
    );
  }
}


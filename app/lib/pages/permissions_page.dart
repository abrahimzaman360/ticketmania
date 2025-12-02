import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({super.key});

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage> {
  Future<Map<String, Map<String, dynamic>>>? _permissionsFuture;

  @override
  void initState() {
    super.initState();
    _permissionsFuture = _checkPermissions();
  }

  void _refreshPermissions() {
    setState(() {
      _permissionsFuture = _checkPermissions();
    });
  }

  Future<Map<String, Map<String, dynamic>>> _checkPermissions() async {
    final permissions = <String, Map<String, dynamic>>{};
    try {
      // Notifications
      final notificationStatus = await Permission.notification.status;
      permissions['notifications'] = {
        'granted': notificationStatus.isGranted,
        'detail': notificationStatus.isGranted
            ? 'Enabled for booking alerts'
            : 'Disabled - enable in device settings',
      };

      // Location
      final locationStatus = await Permission.location.status;
      final locationAlwaysStatus = await Permission.locationAlways.status;
      permissions['location'] = {
        'granted': locationStatus.isGranted,
        'detail': locationAlwaysStatus.isGranted
            ? 'Enabled (always)'
            : locationStatus.isGranted
                ? 'Enabled (while using app)'
                : 'Disabled - required for map and BLE',
      };

      // Bluetooth
      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
      final bluetoothAdvertiseStatus = await Permission.bluetoothAdvertise.status;
      final isBluetoothGranted = bluetoothScanStatus.isGranted &&
          bluetoothConnectStatus.isGranted &&
          bluetoothAdvertiseStatus.isGranted;
      permissions['bluetooth'] = {
        'granted': isBluetoothGranted,
        'detail': isBluetoothGranted
            ? 'Using optimized BLE'
            : 'Disabled - required for auto-validation',
      };
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
    return permissions;
  }

  Widget _buildPermissionTile(
    BuildContext context,
    String title,
    Map<String, dynamic> permissionData,
    IconData icon,
  ) {
    final isGranted = permissionData['granted'] as bool? ?? false;
    final detail = permissionData['detail'] as String? ?? 'Unknown';

    return InkWell(
      onTap: () async {
        // Open app settings to allow user to change permissions
        final opened = await openAppSettings();
        if (opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Return to this screen after changing permissions'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Refresh',
                onPressed: () {
                  if (context.mounted) {
                    _refreshPermissions();
                  }
                },
              ),
            ),
          );
        } else if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open settings. Please go to Settings > Apps > Ticket Mania > Permissions'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      },
      child: ListTile(
        leading: Icon(
          icon,
          color: isGranted
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail,
              style: TextStyle(
                color: isGranted ? Colors.grey[700] : Colors.red[700],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to open settings',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isGranted ? Icons.check_circle : Icons.cancel,
              color: isGranted ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPermissions,
            tooltip: 'Refresh permissions',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Map<String, dynamic>>>(
        future: _permissionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final permissions = snapshot.data ?? {};
              
              return RefreshIndicator(
                onRefresh: () async {
                  _refreshPermissions();
                  // Wait a bit for the refresh to complete
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Info Card
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tap on any permission to open app settings. Some permissions are required for core functionality.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Permissions List
                    Card(
                      child: Column(
                        children: [
                          _buildPermissionTile(
                            context,
                            'Notifications',
                            permissions['notifications'] ?? {'granted': false, 'detail': 'Unknown'},
                            Icons.notifications,
                          ),
                          const Divider(height: 1),
                          _buildPermissionTile(
                            context,
                            'Location',
                            permissions['location'] ?? {'granted': false, 'detail': 'Unknown'},
                            Icons.location_on,
                          ),
                          const Divider(height: 1),
                          _buildPermissionTile(
                            context,
                            'Bluetooth',
                            permissions['bluetooth'] ?? {'granted': false, 'detail': 'Unknown'},
                            Icons.bluetooth,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Help Text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Pull down to refresh permission status after making changes in settings',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}


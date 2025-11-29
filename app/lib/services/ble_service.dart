import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/booking_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/booking.dart';

/// Custom Service UUID for Ticket Mania BLE service
/// Format: 0000XXXX-0000-1000-8000-00805F9B34FB (16-bit UUID)
const String ticketManiaServiceUuid = '0000FEED-0000-1000-8000-00805F9B34FB';
const String ticketManiaCharacteristicUuid = '0000FEED-0001-1000-8000-00805F9B34FB';

/// Method channel for native BLE advertising
const MethodChannel _bleChannel = MethodChannel('com.fishmindlabs.ticketmania/ble_advertising');

class BLEService extends ChangeNotifier {
  final BookingService _bookingService = BookingService();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  BluetoothDevice? _connectedBusDevice;
  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isNativeAdvertising = false;
  Timer? _advertisingTimer;
  List<String> _activeTicketIds = [];

  /// Initialize BLE service and request permissions
  Future<bool> initialize() async {
    try {
      // Check and request Bluetooth permissions
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      final bluetoothAdvertiseStatus = await Permission.bluetoothAdvertise.request();
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      final locationStatus = await Permission.location.request();
      final backgroundLocationStatus = await Permission.locationAlways.request();

      if (bluetoothScanStatus.isDenied ||
          bluetoothAdvertiseStatus.isDenied ||
          bluetoothConnectStatus.isDenied ||
          locationStatus.isDenied ||
          backgroundLocationStatus.isDenied) {
        debugPrint('BLE permissions denied');
        return false;
      }

      // Check if Bluetooth is available
      if (await FlutterBluePlus.isSupported == false) {
        return false;
      }

      // Turn on Bluetooth if off
      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      }

      return true;
    } catch (e) {
      debugPrint('BLE initialization error: $e');
      return false;
    }
  }

  /// Get current BLE status
  bool get isAdvertising => _isAdvertising;
  bool get isScanning => _isScanning;
  bool get isConnected => _connectedBusDevice != null;

  /// Start advertising active tickets via BLE using native implementation
  /// Uses highly optimized native code for battery efficiency
  Future<void> startAdvertising() async {
    if (_isAdvertising) return;

    try {
      // Get active tickets
      final bookings = await _bookingService.getActiveBookings();
      _activeTicketIds = bookings
          .where((b) => b.qrCode != null && (b.status == BookingStatus.confirmed || b.status == BookingStatus.active))
          .map((b) => b.id)
          .toList();

      if (_activeTicketIds.isEmpty) {
        return; // No active tickets to advertise
      }

      // Try to start native BLE advertising first (more battery efficient)
      try {
        final result = await _bleChannel.invokeMethod<bool>(
          'startAdvertising',
          {'ticketIds': _activeTicketIds},
        );
        
        if (result == true) {
          _isNativeAdvertising = true;
          _isAdvertising = true;
          notifyListeners(); // Notify UI of state change
          debugPrint('Started native BLE advertising with ${_activeTicketIds.length} ticket(s)');
          
          // Also start scanning for bus IoT systems
          await startScanning();
          return;
        }
      } catch (e) {
        debugPrint('Native BLE advertising not available, falling back to scanning: $e');
      }

      // Fallback to scanning-only approach if native advertising fails
      _isAdvertising = true;
      notifyListeners(); // Notify UI of state change
      await startScanning();
      
      // Periodically restart scanning to keep it active
      _advertisingTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        if (_isAdvertising && !_isNativeAdvertising) {
          stopScanning().then((_) => startScanning());
        }
      });
    } catch (e) {
      debugPrint('Error starting BLE advertising: $e');
      _isAdvertising = false;
      _isNativeAdvertising = false;
      notifyListeners(); // Notify UI of state change
    }
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;

    // Stop native advertising if active
    if (_isNativeAdvertising) {
      try {
        await _bleChannel.invokeMethod('stopAdvertising');
        _isNativeAdvertising = false;
        debugPrint('Stopped native BLE advertising');
      } catch (e) {
        debugPrint('Error stopping native BLE advertising: $e');
      }
    }

    _isAdvertising = false;
    notifyListeners(); // Notify UI of state change
    await stopScanning();
    _advertisingTimer?.cancel();
  }

  /// Start scanning for bus IoT systems
  Future<void> startScanning() async {
    if (_isScanning) return;

    try {
      _isScanning = true;

      // Scan for devices with our service UUID
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (var result in results) {
            _handleScanResult(result);
          }
        },
        onError: (err) {
          debugPrint('BLE scan error: $err');
        },
      );

      // Start scanning for bus IoT systems with our service UUID
      // Scan continuously (no timeout) for background operation
      await FlutterBluePlus.startScan(
        withServices: [Guid(ticketManiaServiceUuid)],
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint('Error starting BLE scan: $e');
      _isScanning = false;
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
    } catch (e) {
      debugPrint('Error stopping BLE scan: $e');
    }
  }

  /// Handle scan result - check if it's a bus IoT system
  Future<void> _handleScanResult(ScanResult result) async {
    try {
      final device = result.device;
      final advertisementData = result.advertisementData;

      // Check if device has our service UUID
      if (advertisementData.serviceUuids
          .contains(Guid(ticketManiaServiceUuid))) {
        // This is a bus IoT system
        debugPrint('Found bus IoT system: ${device.remoteId}');

        // Connect to the device
        await _connectToBusDevice(device);
      }
    } catch (e) {
      debugPrint('Error handling scan result: $e');
    }
  }

  /// Connect to bus IoT device and validate tickets
  Future<void> _connectToBusDevice(BluetoothDevice device) async {
    try {
      // Don't connect if already connected to this device
      if (_connectedBusDevice?.remoteId == device.remoteId) {
        return;
      }

      // Disconnect from previous device if any
      if (_connectedBusDevice != null) {
        await _disconnectFromBusDevice();
      }

      _connectedBusDevice = device;

      // Connect to device
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Listen for disconnection
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedBusDevice = null;
        }
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find our service
      BluetoothService? ticketService;
      for (var service in services) {
        if (service.uuid == Guid(ticketManiaServiceUuid)) {
          ticketService = service;
          break;
        }
      }

      if (ticketService == null) {
        await _disconnectFromBusDevice();
        return;
      }

      // Find characteristic
      BluetoothCharacteristic? characteristic;
      for (var char in ticketService.characteristics) {
        if (char.uuid == Guid(ticketManiaCharacteristicUuid)) {
          characteristic = char;
          break;
        }
      }

      if (characteristic == null) {
        await _disconnectFromBusDevice();
        return;
      }

      // Send active ticket IDs to bus IoT system
      await _sendTicketIdsToBus(characteristic);

      // Listen for validation responses
      try {
        await characteristic.setNotifyValue(true);
        characteristic.onValueReceived.listen((value) {
          _handleValidationResponse(value);
        });
      } catch (e) {
        // Characteristic might not support notifications
        // In that case, bus system will validate and we'll check status later
        debugPrint('Could not enable notifications: $e');
      }
    } catch (e) {
      debugPrint('Error connecting to bus device: $e');
      _connectedBusDevice = null;
    }
  }

  /// Send active ticket IDs to bus IoT system
  Future<void> _sendTicketIdsToBus(
      BluetoothCharacteristic characteristic) async {
    try {
      // Send ticket IDs as JSON
      final ticketData = {
        'ticket_ids': _activeTicketIds,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonData = jsonEncode(ticketData);
      final bytes = utf8.encode(jsonData);

      await characteristic.write(bytes, withoutResponse: false);
    } catch (e) {
      debugPrint('Error sending ticket IDs: $e');
    }
  }

  /// Handle validation response from bus IoT system
  Future<void> _handleValidationResponse(List<int> value) async {
    try {
      final jsonString = utf8.decode(value);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final validatedTicketId = data['ticket_id'] as String?;
      final isValid = data['valid'] as bool? ?? false;

      if (validatedTicketId != null && isValid) {
        // Validate the ticket
        await _bookingService.validateTicket(
          validatedTicketId,
          validationType: 'ble',
        );

        debugPrint('Ticket validated via BLE: $validatedTicketId');
        
        // Disconnect after validation to allow other devices
        await Future.delayed(const Duration(seconds: 2));
        await _disconnectFromBusDevice();
      }
    } catch (e) {
      debugPrint('Error handling validation response: $e');
    }
  }

  /// Disconnect from bus device
  Future<void> _disconnectFromBusDevice() async {
    try {
      if (_connectedBusDevice != null) {
        await _connectionSubscription?.cancel();
        await _connectedBusDevice!.disconnect();
        _connectedBusDevice = null;
      }
    } catch (e) {
      debugPrint('Error disconnecting from bus device: $e');
    }
  }

  /// Update active tickets and restart advertising if needed
  Future<void> updateActiveTickets() async {
    if (_isAdvertising) {
      // Get updated active tickets
      final bookings = await _bookingService.getActiveBookings();
      final newTicketIds = bookings
          .where((b) => b.qrCode != null && (b.status == BookingStatus.confirmed || b.status == BookingStatus.active))
          .map((b) => b.id)
          .toList();

      // Update native advertising if active
      if (_isNativeAdvertising) {
        try {
          await _bleChannel.invokeMethod(
            'updateTicketIds',
            {'ticketIds': newTicketIds},
          );
          _activeTicketIds = newTicketIds;
          debugPrint('Updated native BLE advertising with ${newTicketIds.length} ticket(s)');
          return;
        } catch (e) {
          debugPrint('Error updating native BLE advertising: $e');
          // Fallback to restart
        }
      }

      // Restart advertising with new tickets
      await stopAdvertising();
      _activeTicketIds = newTicketIds;
      await startAdvertising();
    }
  }
  
  /// Check if native advertising is currently active
  Future<bool> isNativeAdvertising() async {
    if (!_isNativeAdvertising) return false;
    
    try {
      final result = await _bleChannel.invokeMethod<bool>('isAdvertising');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Cleanup
  @override
  void dispose() {
    stopScanning();
    stopAdvertising();
    _disconnectFromBusDevice();
    _advertisingTimer?.cancel();
    super.dispose();
  }
}


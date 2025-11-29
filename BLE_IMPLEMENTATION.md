# BLE Auto-Validation Implementation

## Overview
The app now uses Bluetooth Low Energy (BLE) for automatic ticket validation when users are in range of bus IoT systems.

## Architecture

### Service UUID
- **Service UUID**: `0000FEED-0000-1000-8000-00805F9B34FB`
- **Characteristic UUID**: `0000FEED-0001-1000-8000-00805F9B34FB`

### How It Works

1. **Phone Side (This App)**:
   - Scans for bus IoT systems advertising our service UUID
   - When a bus IoT system is detected, connects to it
   - Sends active ticket IDs to the bus system
   - Receives validation confirmation from the bus system
   - Automatically validates tickets when confirmed

2. **Bus IoT System**:
   - Advertises with our service UUID
   - Scans for phones with active tickets (or phones connect to it)
   - Receives ticket IDs from connected phones
   - Validates tickets and sends confirmation
   - Processes payment if needed

## Current Implementation

### BLE Service (`lib/services/ble_service.dart`)
- **Scanning**: Continuously scans for bus IoT systems
- **Connection**: Automatically connects when bus system is detected
- **Ticket Broadcasting**: Sends active ticket IDs to bus system
- **Auto-Validation**: Validates tickets when bus system confirms

### Limitations
- **Advertising**: `flutter_blue_plus` doesn't support BLE advertising directly
  - For production, you'll need native platform code (Android/iOS) to advertise ticket IDs
  - Current implementation uses scanning approach (bus system scans for phones)
  - Alternative: Use a different BLE library that supports advertising

### Permissions Required
- Bluetooth Scan (Android 12+)
- Bluetooth Connect (Android 12+)
- Bluetooth (Android 11 and below)
- Location (required for BLE scanning on Android)

## Background Service

The BLE service runs in the background:
- Automatically starts when user is authenticated
- Continuously scans for bus IoT systems
- Updates when new tickets are booked
- Can be enabled/disabled from Settings (More page)

## Future Enhancements

1. **Native BLE Advertising**:
   - Implement native Android/iOS code to advertise ticket IDs
   - This allows phones to be discovered by bus systems

2. **Background Service**:
   - Implement proper Android/iOS background service
   - Keep BLE scanning active even when app is in background

3. **Range Detection**:
   - Use RSSI (signal strength) to detect when in threshold range
   - Only validate when signal is strong enough

4. **Manual Validation**:
   - Add option to manually trigger validation via BLE
   - Useful for offline scenarios

## Testing

To test BLE functionality:
1. Enable "Auto Validation (BLE)" in Settings (More page)
2. Ensure Bluetooth and Location permissions are granted
3. Have active tickets in your account
4. Connect to a bus IoT system (or simulate one)
5. Tickets should automatically validate when in range

## Notes

- The service UUID `0000FEED` is a custom 16-bit UUID
- For production, register your own UUID with Bluetooth SIG
- Ensure bus IoT systems use the same service UUID
- Consider implementing encryption for ticket ID transmission


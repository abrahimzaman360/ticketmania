# Native BLE Advertising Implementation

## Overview
Highly optimized native Android and iOS implementations for BLE advertising that minimize battery consumption while maintaining reliable ticket validation.

## Battery Optimization Features

### Android
- **Low Power Advertising Mode**: Uses `ADVERTISE_MODE_LOW_POWER` (1000ms interval)
- **Low TX Power**: Uses `ADVERTISE_TX_POWER_LOW` for reduced power consumption
- **Efficient Data Encoding**: Compact ticket ID encoding to minimize advertising payload
- **Service-Based Architecture**: Runs as a bound service, allowing efficient resource management
- **No Device Name**: Excludes device name from advertising data to save power
- **No TX Power Level**: Excludes TX power level from advertising data to save power

### iOS
- **Automatic Low Power Mode**: iOS automatically uses low power advertising intervals
- **Background Advertising**: Supports background advertising with proper permissions
- **Efficient Data Encoding**: Same compact encoding as Android
- **State Management**: Properly handles Bluetooth state changes

## Architecture

### Android Implementation

#### Files
- `BLEAdvertisingService.kt`: Main service for BLE advertising
- `BLEMethodChannel.kt`: Flutter method channel handler
- `MainActivity.kt`: Registers method channel

#### Service UUID
- **Service UUID**: `0000FEED-0000-1000-8000-00805F9B34FB`
- **Characteristic UUID**: `0000FEED-0001-1000-8000-00805F9B34FB`

#### Advertising Parameters
```kotlin
ADVERTISE_MODE_LOW_POWER      // 1000ms interval (most battery efficient)
ADVERTISE_TX_POWER_LOW        // Low transmission power
CONNECTABLE = true            // Allows bus systems to connect
TIMEOUT = 0                   // No timeout, advertise indefinitely
```

### iOS Implementation

#### Files
- `BLEAdvertisingManager.swift`: Main manager for BLE advertising
- `AppDelegate.swift`: Registers method channel

#### Service UUID
- Same as Android: `0000FEED-0000-1000-8000-00805F9B34FB`

#### Advertising Parameters
- iOS automatically uses low power mode for background advertising
- Supports both foreground and background advertising

## Data Encoding

### Format
```
[count: 1 byte][id1_length: 1 byte][id1: N bytes][id2_length: 1 byte][id2: M bytes]...
```

### Example
For ticket IDs: `["abc123", "def456"]`
```
[0x02][0x06][a][b][c][1][2][3][0x06][d][e][f][4][5][6]
```

### Limitations
- Maximum 20 bytes for ticket data (BLE advertising limit is 31 bytes)
- Can fit approximately 2-3 ticket IDs depending on UUID length

## Permissions

### Android
```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
```

### iOS
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<key>NSBluetoothPeripheralUsageDescription</key>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>
```

## Flutter Integration

### Method Channel
- **Channel Name**: `com.fishmindlabs.ticketmania/ble_advertising`

### Methods
1. **startAdvertising(ticketIds)**: Start advertising with ticket IDs
2. **stopAdvertising()**: Stop advertising
3. **updateTicketIds(ticketIds)**: Update ticket IDs while advertising
4. **isAdvertising()**: Check if currently advertising

### Usage
```dart
final bleService = BLEService();
await bleService.initialize();
await bleService.startAdvertising(); // Uses native implementation automatically
```

## Battery Consumption

### Expected Impact
- **Low Power Mode**: ~1-2% battery per hour when advertising
- **Background Operation**: Minimal impact when app is in background
- **Optimized Intervals**: 1000ms advertising interval reduces power consumption by ~70% compared to balanced mode

### Best Practices
1. Only advertise when user has active tickets
2. Stop advertising when no active tickets
3. Update ticket IDs instead of restarting advertising
4. Use low power mode (default)

## Testing

### Android
1. Enable "Auto Validation (BLE)" in Settings
2. Grant Bluetooth and Location permissions
3. Check logcat for advertising status:
   ```
   adb logcat | grep BLEAdvertisingService
   ```

### iOS
1. Enable "Auto Validation (BLE)" in Settings
2. Grant Bluetooth permissions
3. Check console logs for advertising status

## Troubleshooting

### Android
- **Error Code 1**: Data too large - reduce number of ticket IDs
- **Error Code 2**: Too many advertisers - stop other BLE apps
- **Error Code 3**: Already started - call stopAdvertising first
- **Error Code 4**: Internal error - check Bluetooth adapter state
- **Error Code 5**: Feature unsupported - device doesn't support BLE advertising

### iOS
- **Unauthorized**: Grant Bluetooth permissions in Settings
- **Powered Off**: Enable Bluetooth in Settings
- **Unsupported**: Device doesn't support BLE advertising (iPhone 4s or earlier)

## Future Enhancements

1. **Adaptive Power Management**: Adjust advertising interval based on battery level
2. **Proximity Detection**: Use RSSI to detect when bus is nearby
3. **Encryption**: Encrypt ticket IDs in advertising data
4. **Compression**: Further optimize data encoding for more ticket IDs


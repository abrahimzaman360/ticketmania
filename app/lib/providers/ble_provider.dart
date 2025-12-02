import 'package:flutter_riverpod/legacy.dart';
import '../services/ble_service.dart';

/// Provider for BLE service
final bleServiceProvider = ChangeNotifierProvider<BLEService>((ref) {
  return BLEService();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/station_repository.dart';
import '../providers/connectivity_provider.dart';
import '../models/station.dart';

/// Provider for stations
final stationsProvider = FutureProvider<List<Station>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final repository = ref.watch(stationRepositoryProvider(isOnline));
  return repository.getStations();
});


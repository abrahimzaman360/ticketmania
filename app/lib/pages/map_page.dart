import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/booking_service.dart';
import '../models/station.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class MapPage extends StatefulWidget {
  final Station? selectedStation;
  final Function(Station)? onStationSelected;

  const MapPage({super.key, this.selectedStation, this.onStationSelected});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final BookingService _bookingService = BookingService();
  List<Station> _stations = [];
  Station? _selectedStation;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isLocationLoading = false;

  // For OpenStreetMap (flutter_map)
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _selectedStation = widget.selectedStation;
    _loadData();
    _getCurrentLocation();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final stations = await _bookingService.getStations();
      if (!mounted) return;
      setState(() {
        _stations = stations;
        _isLoading = false;
      });

      // Center map on selected station or first station (only if map is ready)
      // This will be handled in onMapReady callback if map isn't ready yet
      if (_isMapReady && mounted) {
        _updateMapCenter();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading stations: $e')));
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLocationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable them.',
              ),
            ),
          );
        }
        if (!mounted) return;
        setState(() => _isLocationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() => _isLocationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isLocationLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isLocationLoading = false;
      });

      // Center map on current location (only if map is ready)
      if (_isMapReady && mounted) {
        _centerOnLocation(position);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocationLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  void _centerOnStation(Station station) {
    if (_isMapReady && mounted) {
      try {
        _mapController.move(LatLng(station.latitude, station.longitude), 14.0);
      } catch (e) {
        // Map might not be fully ready yet, ignore the error
        debugPrint('Error centering on station: $e');
      }
    }
  }

  void _centerOnLocation(Position position) {
    if (_isMapReady && mounted) {
      try {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          13.0,
        );
      } catch (e) {
        // Map might not be fully ready yet, ignore the error
        debugPrint('Error centering on location: $e');
      }
    }
  }

  void _updateMapCenter() {
    if (!_isMapReady || !mounted) return;

    // Priority: selected station > current location > first station
    if (_selectedStation != null) {
      _centerOnStation(_selectedStation!);
    } else if (_currentPosition != null) {
      _centerOnLocation(_currentPosition!);
    } else if (_stations.isNotEmpty) {
      _centerOnStation(_stations.first);
    }
  }

  bool get _isApplePlatform {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_isLocationLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _getCurrentLocation,
              tooltip: 'My Location',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isApplePlatform
          ? _buildAppleMap()
          : _buildOpenStreetMap(),
      floatingActionButton: _selectedStation != null
          ? FloatingActionButton.extended(
              onPressed: widget.onStationSelected != null
                  ? () {
                      widget.onStationSelected!(_selectedStation!);
                      Navigator.pop(context);
                    }
                  : null,
              icon: const Icon(Icons.check),
              label: Text('Select ${_selectedStation!.name}'),
            )
          : null,
    );
  }

  Widget _buildOpenStreetMap() {
    if (_stations.isEmpty) {
      return const Center(child: Text('No stations available'));
    }

    final centerLat = _currentPosition?.latitude ?? _stations.first.latitude;
    final centerLng = _currentPosition?.longitude ?? _stations.first.longitude;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(centerLat, centerLng),
        initialZoom: 12.0,
        onTap: (tapPosition, point) {
          // Deselect station on map tap
          if (mounted) {
            setState(() => _selectedStation = null);
          }
        },
        onMapReady: () {
          // Map is now ready, we can use the controller
          if (mounted) {
            setState(() {
              _isMapReady = true;
            });
            // Update map center after a short delay to ensure map is fully rendered
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _updateMapCenter();
              }
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fishmindlabs.ticketmania',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            // Current location marker
            if (_currentPosition != null)
              Marker(
                point: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            // Station markers
            ..._stations.map((station) {
              final isSelected = _selectedStation?.id == station.id;
              return Marker(
                point: LatLng(station.latitude, station.longitude),
                width: isSelected ? 60 : 50,
                height: isSelected ? 60 : 50,
                child: GestureDetector(
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _selectedStation = station;
                      });
                      _centerOnStation(station);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.train,
                      color: Colors.white,
                      size: isSelected ? 30 : 25,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildAppleMap() {
    // For iOS/macOS, we use OpenStreetMap via flutter_map
    // Note: To use native Apple Maps, you would need to implement
    // platform channels or use a package like mapkit_flutter
    // For now, we use OpenStreetMap which works well on all platforms
    return _buildOpenStreetMap();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

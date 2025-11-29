# Map Integration Documentation

## Overview

The app now uses **OpenStreetMap** (via `flutter_map`) for all platforms, providing a free, open-source mapping solution that works consistently across Android, iOS, macOS, Linux, Windows, and Web.

## Current Implementation

### ✅ What's Implemented

1. **Map Page** (`lib/pages/map_page.dart`)
   - Interactive map showing all stations
   - Custom markers for stations (red circles with train icons)
   - Current location marker (blue icon)
   - Tap stations to select them
   - "My Location" button to center on user's location
   - Station selection returns selected station to booking flow

2. **Integration Points**
   - Home screen: Map icon in app bar to view all stations
   - Booking page: Map icon next to station selection to pick from map
   - Station markers are clickable and show selection state

3. **Features**
   - Real-time location tracking
   - Station markers with custom styling
   - Map centering on selection
   - Location permissions handling
   - Works offline (cached tiles)

### 📦 Packages Used

- **flutter_map**: ^7.0.2 - OpenStreetMap integration
- **latlong2**: ^0.9.1 - Geographic coordinates handling
- **geolocator**: ^12.0.0 - Location services

### 🔧 Platform Configuration

#### Android
- ✅ Location permissions added to `AndroidManifest.xml`
- ✅ Internet permission for map tiles

#### iOS/macOS
- ✅ Location usage descriptions added to `Info.plist`
- ✅ Works with OpenStreetMap tiles

## Using Native Apple Maps on iOS/macOS

Currently, the app uses OpenStreetMap on all platforms for consistency. To use native Apple Maps on iOS/macOS, you have these options:

### Option 1: Platform Channels (Recommended for Native Experience)

This requires creating native Swift/Objective-C code:

1. **Create Platform Channel**:
   - iOS: Create a `UIViewRepresentable` wrapper in Swift
   - macOS: Create an `NSViewRepresentable` wrapper in Swift
   - Use `MethodChannel` to communicate between Flutter and native code

2. **Implementation Steps**:
   ```swift
   // iOS: ios/Runner/MapView.swift
   import MapKit
   import Flutter
   
   class MapViewFactory: NSObject, FlutterPlatformViewFactory {
       func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
           return MapView(frame: frame, viewId: viewId, args: args)
       }
   }
   
   class MapView: NSObject, FlutterPlatformView, MKMapViewDelegate {
       let mapView: MKMapView
       
       init(frame: CGRect, viewId: Int64, args: Any?) {
           mapView = MKMapView(frame: frame)
           super.init()
           mapView.delegate = self
           // Configure map
       }
       
       func view() -> UIView {
           return mapView
       }
   }
   ```

3. **Register in AppDelegate**:
   ```swift
   let mapFactory = MapViewFactory()
   registrar.register(mapFactory, withId: "apple-map-view")
   ```

### Option 2: Use Apple Maps Tile Provider (Easier)

You can use Apple Maps tiles with `flutter_map` by using a custom tile provider:

```dart
TileLayer(
  urlTemplate: 'https://maps.apple.com/maps?q={lat},{lng}',
  // Note: This requires proper licensing and may have usage restrictions
)
```

**Note**: Apple Maps tiles have usage restrictions. Check Apple's terms of service.

### Option 3: Hybrid Approach

Use OpenStreetMap by default, but allow users to switch to Apple Maps on iOS:

```dart
bool useAppleMaps = Platform.isIOS && _preferences.getBool('use_apple_maps') ?? false;

if (useAppleMaps) {
  // Show native Apple Maps via platform channel
} else {
  // Show OpenStreetMap
}
```

## Current Map Features

### Station Markers
- **Color**: Red circles for stations, green when selected
- **Icon**: Train icon (Icons.train)
- **Size**: 50px normal, 60px when selected
- **Interaction**: Tap to select, shows station name

### Current Location
- **Color**: Blue
- **Icon**: My Location icon (Icons.my_location)
- **Size**: 40px
- **Auto-center**: Map centers on location when obtained

### Map Controls
- **Zoom**: Pinch to zoom, double-tap to zoom in
- **Pan**: Drag to move around
- **My Location Button**: Centers map on user's current location

## Usage Examples

### Opening Map from Home Screen
```dart
IconButton(
  icon: Icon(Icons.map),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapPage()),
    );
  },
)
```

### Selecting Station from Map
```dart
final station = await Navigator.push<Station>(
  context,
  MaterialPageRoute(
    builder: (context) => MapPage(),
  ),
);
if (station != null) {
  // Use selected station
}
```

### Pre-selecting a Station
```dart
MapPage(selectedStation: myStation)
```

## Performance Considerations

1. **Tile Caching**: `flutter_map` caches tiles automatically
2. **Marker Optimization**: Only visible markers are rendered
3. **Location Updates**: Location is fetched once, not continuously
4. **Memory**: Map tiles are cached but limited by device memory

## Future Enhancements

- [ ] Route visualization between stations
- [ ] Search functionality for stations
- [ ] Clustering for many stations
- [ ] Custom map styles
- [ ] Offline map downloads
- [ ] Native Apple Maps integration (if needed)
- [ ] Directions integration
- [ ] Real-time transit information

## Troubleshooting

### Map Not Loading
- Check internet connection (required for initial tile load)
- Verify location permissions are granted
- Check console for tile loading errors

### Location Not Working
- Ensure location permissions are granted
- Check if location services are enabled on device
- Verify `Info.plist` (iOS) or `AndroidManifest.xml` (Android) has correct permissions

### Markers Not Showing
- Verify stations are loaded from database
- Check station coordinates are valid
- Ensure map is zoomed to appropriate level

## License Notes

- **OpenStreetMap**: Free and open-source, requires attribution
- **Apple Maps**: Requires Apple Developer account and follows Apple's terms of service
- Current implementation uses OpenStreetMap which is free for all use cases

## Testing

Test the map on:
- ✅ Android devices/emulators
- ✅ iOS devices/simulators
- ✅ macOS
- ✅ Web browsers
- ✅ Linux (if applicable)
- ✅ Windows (if applicable)


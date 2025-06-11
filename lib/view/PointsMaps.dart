import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class Pointsmaps extends StatefulWidget {
  const Pointsmaps({super.key});

  @override
  State<Pointsmaps> createState() => _PointsmapsState();
}

class _PointsmapsState extends State<Pointsmaps> {
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotationManager? pointAnnotationManager;
  StreamSubscription<gl.Position>? userPositionStream;
  double? currentLatitude;
  double? currentLongitude;
  String _statusMessage = 'Initializing map...';
  final double destinationLongitude = 39.2851; // Destination near Dar es Salaam
  final double destinationLatitude = -6.8227;
  bool _sourceInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    pointAnnotationManager?.deleteAll();
    _removeRouteLayer();
    mapboxMapController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      setState(() {
        _statusMessage = 'Location permission granted.';
      });
      _setupPositionTracking();
    } else if (status.isDenied) {
      setState(() {
        _statusMessage = 'Location permission denied. Map features disabled.';
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _statusMessage =
            'Location permission permanently denied. Please enable in settings.';
      });
      await openAppSettings();
    }
  }

  Future<void> _setupPositionTracking() async {
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusMessage = 'Location services are disabled.';
      });
      if (mapboxMapController != null) {
        mapboxMapController!.setCamera(
          mp.CameraOptions(
            center: mp.Point(coordinates: mp.Position(39.2851, -6.8227)),
            zoom: 15,
          ),
        );
        _updateMarkers(-6.8227, 39.2851);
      }
      return;
    }

    gl.LocationSettings locationSettings = const gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 10,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (gl.Position position) {
        setState(() {
          currentLatitude = position.latitude;
          currentLongitude = position.longitude;
          _statusMessage = 'Location updated.';
        });

        debugPrint(
          'Location received: Lat=${position.latitude}, Lon=${position.longitude}',
        );

        if (mapboxMapController != null) {
          mapboxMapController!.setCamera(
            mp.CameraOptions(
              center: mp.Point(
                coordinates: mp.Position(position.longitude, position.latitude),
              ),
              zoom: 15,
            ),
          );
          _updateMarkers(position.latitude, position.longitude);
          if (_sourceInitialized) {
            _fetchAndDrawRoute(
              position.longitude,
              position.latitude,
              destinationLongitude,
              destinationLatitude,
            );
          }
        } else {
          debugPrint('Map not initialized yet.');
        }
      },
      onError: (e) {
        setState(() {
          _statusMessage = 'Error getting location: $e';
        });
        debugPrint('Location stream error: $e');
      },
    );
  }

  void _onMapCreated(mp.MapboxMap controller) {
    setState(() {
      mapboxMapController = controller;
    });

    // Delay to stabilize Android surface
    Future.delayed(const Duration(milliseconds: 100), () {
      // Initialize PointAnnotationManager
      mapboxMapController!.annotations
          .createPointAnnotationManager()
          .then((manager) {
            setState(() {
              pointAnnotationManager = manager;
              debugPrint('PointAnnotationManager initialized.');
            });
            if (currentLatitude == null || currentLongitude == null) {
              _updateMarkers(-6.8227, 39.2851);
            }
          })
          .catchError((e) {
            debugPrint('Error creating PointAnnotationManager: $e');
            setState(() {
              _statusMessage = 'Error initializing map annotations: $e';
            });
          });

      // Initialize GeoJSON source and line layer
      _initializeRouteLayer().then((_) {
        setState(() {
          _sourceInitialized = true;
        });
        if (currentLatitude != null && currentLongitude != null) {
          _fetchAndDrawRoute(
            currentLongitude!,
            currentLatitude!,
            destinationLongitude,
            destinationLatitude,
          );
        }
      });

      mapboxMapController?.location.updateSettings(
        mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
      );
    });
  }

  Future<void> _initializeRouteLayer() async {
    try {
      // Add empty GeoJSON source
      await mapboxMapController!.style.addStyleSource(
        'route-source',
        jsonEncode({
          'type': 'geojson',
          'data': {'type': 'FeatureCollection', 'features': []},
        }),
      );

      // Add line layer
      await mapboxMapController!.style.addStyleLayer(
        {
              'id': 'route-layer',
              'type': 'line',
              'source': 'route-source',
              'slot': 'middle',
              'paint': {
                'line-color': '#0000FF',
                'line-width': 4.0,
                'line-opacity': 0.8,
              },
            }
            as String,
        null,
      );

      debugPrint('GeoJSON source and line layer initialized.');
    } catch (e) {
      debugPrint('Error initializing route layer: $e');
      setState(() {
        _statusMessage = 'Error initializing route layer: $e';
      });
    }
  }

  Future<void> _updateMarkers(double latitude, double longitude) async {
    if (pointAnnotationManager == null) {
      debugPrint('PointAnnotationManager is null, cannot update markers.');
      return;
    }

    try {
      await pointAnnotationManager!.deleteAll();
      debugPrint('Cleared existing point annotations.');

      // Create marker for user's location
      await pointAnnotationManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(coordinates: mp.Position(longitude, latitude)),
          symbolSortKey: 1,
          iconSize: 1.0,
          iconImage: 'pin', // Fallback icon
          textField: 'Current Location',
          textSize: 12,
          textOffset: [0, -1.5],
        ),
      );

      // Create marker for destination
      await pointAnnotationManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(destinationLongitude, destinationLatitude),
          ),
          symbolSortKey: 1,
          iconSize: 1.0,
          iconImage: 'pin', // Fallback icon
          textField: 'Destination',
          textSize: 12,
          textOffset: [0, -1.5],
        ),
      );
      debugPrint(
        'Markers created at Lat=$latitude, Lon=$longitude and Destination Lat=$destinationLatitude, Lon=$destinationLongitude',
      );
    } catch (e) {
      debugPrint('Error creating markers: $e');
      setState(() {
        _statusMessage = 'Error creating markers: $e';
      });
    }
  }

  Future<void> _fetchAndDrawRoute(
    double startLon,
    double startLat,
    double endLon,
    double endLat,
  ) async {
    if (mapboxMapController == null || !_sourceInitialized) {
      debugPrint(
        'MapboxMapController or source not initialized, cannot draw route.',
      );
      return;
    }

    try {
      final String accessToken =
          'pk.eyJ1IjoicGltYXRlY2giLCJhIjoiY21iYWpvOWRlMDYwajJsc2F5MngwZjJ5aiJ9.ESREiHBRgbEpEuf2qR3rhA'; // Verify this token
      final String url =
          'https://api.mapbox.com/directions/v5/mapbox/walking/$startLon,$startLat;$endLon,$endLat?geometries=geojson&access_token=$accessToken';

      final response = await http.get(Uri.parse(url));
      debugPrint(
        'Directions API response: ${response.body}',
      ); // Debug API response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final geometry = data['routes'][0]['geometry'];
        final coordinates =
            (geometry['coordinates'] as List<dynamic>)
                .map((coord) => [coord[0], coord[1]])
                .toList();

        // Update GeoJSON source data
        await mapboxMapController!.style.setStyleSourceProperty(
          'route-source',
          'data',
          jsonEncode({
            'type': 'Feature',
            'geometry': {'type': 'LineString', 'coordinates': coordinates},
          }),
        );

        debugPrint(
          'Route drawn from ($startLon, $startLat) to ($endLon, $endLat)',
        );
      } else {
        debugPrint('Failed to fetch route: ${response.statusCode}');
        setState(() {
          _statusMessage = 'Failed to fetch route: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
      setState(() {
        _statusMessage = 'Error drawing route: $e';
      });
    }
  }

  Future<void> _removeRouteLayer() async {
    if (mapboxMapController == null) return;
    try {
      if (await mapboxMapController!.style.styleSourceExists('route-source')) {
        await mapboxMapController!.style.setStyleSourceProperty(
          'route-source',
          'data',
          jsonEncode({'type': 'FeatureCollection', 'features': []}),
        );
      }
      debugPrint('Cleared existing route data.');
    } catch (e) {
      debugPrint('Error removing route layer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Navigation'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: mp.MapWidget(
              key: const ValueKey('mapWidget'),
              onMapCreated: _onMapCreated,
              styleUri: 'mapbox://styles/pimatech/cmbajxlw700vo01r4bqbmdrnk',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (currentLatitude != null && currentLongitude != null)
                  Text(
                    'Current: Lat ${currentLatitude!.toStringAsFixed(6)}, Lon ${currentLongitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  const Text(
                    'Waiting for location...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 10),
                Text(
                  'Destination: Lat ${destinationLatitude.toStringAsFixed(6)}, Lon ${destinationLongitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 14, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

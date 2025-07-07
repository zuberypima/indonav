import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:indonav/view/HomePage.dart';

class CampasMapView extends StatefulWidget {
  final double targetLatitude;
  final double targetLongitude;
  final double visitorLatitude;
  final double visitorLongitude;
  final double distance;

  const CampasMapView({
    super.key,
    required this.targetLatitude,
    required this.targetLongitude,
    required this.visitorLatitude,
    required this.visitorLongitude,
    required this.distance,
  });

  @override
  State<CampasMapView> createState() => _CampasMapViewState();
}

class _CampasMapViewState extends State<CampasMapView> {
  mp.MapboxMap? mapboxMapController;
  StreamSubscription<gl.Position>? userPositionStream;
  gl.Position? _currentPosition;
  String? _routeLayerId;
  bool _isLoadingRoute = false;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    _currentPosition = gl.Position(
      latitude: widget.visitorLatitude,
      longitude: widget.visitorLongitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    _requestLocationPermission();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            print('Back button pressed, navigating to HomePage');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(visitorName: ''),
              ),
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Distance to Department: ${(widget.distance / 1000).toStringAsFixed(2)} km (approx.)',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (widget.targetLatitude.isFinite &&
              widget.targetLongitude.isFinite &&
              widget.visitorLatitude.isFinite &&
              widget.visitorLongitude.isFinite)
            mp.MapWidget(
              key: const ValueKey('mapWidget'),
              onMapCreated: _onMapCreated,
              styleUri: 'mapbox://styles/mapbox/satellite-streets-v12',
            )
          else
            const Center(
              child: Text(
                'Invalid coordinates. Please try again.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          if (_isLoadingRoute)
            const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            ),
          if (_routeError != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.red,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Failed to load route: $_routeError',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _routeError = null;
                            _isLoadingRoute = true;
                          });
                          _fetchAndDrawRoute();
                        },
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    setState(() {
      mapboxMapController = controller;
    });

    print('Map created, initializing location and marker');

    // Enable user location
    await mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    // Center map on target coordinates
    await mapboxMapController?.setCamera(
      mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(
            widget.targetLongitude,
            widget.targetLatitude,
          ),
        ),
        zoom: 15,
      ),
    );

    // Add marker for department
    final pointAnnotationManager =
        await mapboxMapController?.annotations.createPointAnnotationManager();
    await pointAnnotationManager?.create(
      mp.PointAnnotationOptions(
        geometry: mp.Point(
          coordinates: mp.Position(
            widget.targetLongitude,
            widget.targetLatitude,
          ),
        ),
        iconImage: 'marker',
        iconSize: 0.5,
      ),
    );
    print(
      'Added department marker at (${widget.targetLatitude}, ${widget.targetLongitude})',
    );

    // Draw route if current position exists
    if (_currentPosition != null) {
      setState(() {
        _isLoadingRoute = true;
      });
      await _fetchAndDrawRoute();
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      print('Location permission granted');
      await _setupPositionTracking();
    } else if (status.isDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission denied'),
          backgroundColor: Colors.red,
        ),
      );
      print('Location permission denied');
    } else if (status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission permanently denied. Please enable in settings.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      print('Location permission permanently denied');
      await openAppSettings();
    }
  }

  Future<void> _setupPositionTracking() async {
    if (!await gl.Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled'),
          backgroundColor: Colors.red,
        ),
      );
      print('Location services disabled');
      return;
    }

    final gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 10,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (gl.Position position) {
        if (!mounted || mapboxMapController == null) return;

        setState(() {
          _currentPosition = position;
        });

        print(
          'Current position: lat=${position.latitude}, lng=${position.longitude}',
        );

        setState(() {
          _isLoadingRoute = true;
        });
        _fetchAndDrawRoute();
      },
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        print('Location error: $e');
      },
    );
  }

  Future<void> _fetchAndDrawRoute() async {
    if (_currentPosition == null || mapboxMapController == null) {
      print('No route drawn: _currentPosition or mapboxMapController is null');
      setState(() {
        _isLoadingRoute = false;
        _routeError = 'Map or location data unavailable';
      });
      return;
    }

    final startLat = _currentPosition!.latitude;
    final startLng = _currentPosition!.longitude;
    final endLat = widget.targetLatitude;
    final endLng = widget.targetLongitude;

    if (!startLat.isFinite ||
        !startLng.isFinite ||
        !endLat.isFinite ||
        !endLng.isFinite) {
      print(
        'Invalid coordinates: start=($startLat, $startLng), end=($endLat, $endLng)',
      );
      setState(() {
        _isLoadingRoute = false;
        _routeError = 'Invalid coordinates';
      });
      return;
    }

    print(
      'Fetching route: start=($startLat, $startLng), end=($endLat, $endLng)',
    );

    final accessToken = await mp.MapboxOptions.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      print('Mapbox access token is missing');
      setState(() {
        _isLoadingRoute = false;
        _routeError = 'Mapbox access token missing';
      });
      return;
    }

    final url =
        'https://api.mapbox.com/directions/v5/mapbox/walking/$startLng,$startLat;$endLng,$endLat?geometries=geojson&access_token=$accessToken';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      print('Mapbox API response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch route: ${response.statusCode} - ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      print('Mapbox response: ${response.body}');
      if (data['routes'] == null || data['routes'].isEmpty) {
        throw Exception(
          'No routes found: ${data['message'] ?? 'Unknown error'}',
        );
      }

      final routeGeometry = data['routes'][0]['geometry'];
      final coordinates =
          (routeGeometry['coordinates'] as List)
              .map((coord) => mp.Position(coord[0], coord[1]))
              .toList();

      print('Route coordinates: ${coordinates.length} points');

      // Remove existing route layer and source if present
      if (_routeLayerId != null) {
        try {
          await mapboxMapController?.style.removeStyleLayer(_routeLayerId!);
          print('Removed existing route layer: $_routeLayerId');
        } catch (e) {
          print('Failed to remove route layer $_routeLayerId: $e');
        }
        try {
          await mapboxMapController?.style.removeStyleSource('route-source');
          print('Removed existing route source: route-source');
        } catch (e) {
          print('Failed to remove route source: $e');
        }
      }

      // Add route source
      final sourceData = {
        'type': 'geojson',
        'data': {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates.map((p) => [p.lng, p.lat]).toList(),
          },
        },
      };
      await mapboxMapController?.style.addStyleSource(
        'route-source',
        jsonEncode(sourceData),
      );
      print('Added route source: route-source');

      // Add route layer
      _routeLayerId = 'route-layer-${DateTime.now().millisecondsSinceEpoch}';
      final layerData = {
        'id': _routeLayerId!,
        'type': 'line',
        'source': 'route-source',
        'paint': {
          'line-color': 'rgb(255, 69, 0)', // Deep orange
          'line-width': 5.0,
          'line-opacity': 0.8,
        },
      };
      await mapboxMapController?.style.addStyleLayer(
        jsonEncode(layerData),
        null,
      );
      print('Route layer added: $_routeLayerId');

      setState(() {
        _isLoadingRoute = false;
        _routeError = null;
      });
    } catch (e) {
      if (!mounted) return;
      print('Route error: $e');
      setState(() {
        _isLoadingRoute = false;
        _routeError = e.toString();
      });
    }
  }
}

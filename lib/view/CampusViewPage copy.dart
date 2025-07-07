import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:indonav/view/loginpage.dart';

class CampusViewPage extends StatefulWidget {
  const CampusViewPage({super.key});

  @override
  _CampusViewPageState createState() => _CampusViewPageState();
}

class _CampusViewPageState extends State<CampusViewPage> {
  MapboxMap? _mapboxMap;
  String? _polylineLayerId;
  bool _isLoadingMap = true;
  String? _mapError;

  // Mapbox access token
  static const String mapboxAccessToken =
      'pk.eyJ1IjoicGltYXRlY2giLCJhIjoiY21jbWc0YWRtMDI1bTJpc2VzNzF5djBucyJ9.vHTjfBLCIYT7opZOHkXqAg';

  // GeoJSON coordinates as Position (lng, lat) for Mapbox
  static List<Position> _polylinePoints = [
    Position(-8.938923949247453, 33.41218212157679),
    Position(-8.938967228229146, 33.42191913633292),
    Position(-8.944084931517096, 33.42195199465036),
    Position(-8.944247225370162, 33.411590671862086),
    Position(-8.93885903076594, 33.41183163285689),
    Position(-8.938902309755349, 33.41225879098451),
    Position(-8.938923949247453, 33.412565468614076),
  ];

  // Calculate initial camera position (average of coordinates)
  static final CameraOptions _initialCameraPosition = _calculateAveragePosition(
    _polylinePoints,
  );

  static CameraOptions _calculateAveragePosition(List<Position> points) {
    // Fallback for empty or invalid points
    if (points.isEmpty) {
      return CameraOptions(
        center: Point(coordinates: Position(-8.9410, 33.4157)),
        zoom: 16.0,
      );
    }

    double sumLat = 0;
    double sumLng = 0;
    int validPoints = 0;

    for (var point in points) {
      if (point.lat.isFinite && point.lng.isFinite) {
        sumLat += point.lat;
        sumLng += point.lng;
        validPoints++;
      }
    }

    // Use fallback if no valid points
    if (validPoints == 0) {
      return CameraOptions(
        center: Point(coordinates: Position(-8.9410, 33.4157)),
        zoom: 16.0,
      );
    }

    return CameraOptions(
      center: Point(
        coordinates: Position(sumLng / validPoints, sumLat / validPoints),
      ),
      zoom: 16.0,
    );
  }

  @override
  void initState() {
    super.initState();
    // Set Mapbox access token
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  @override
  void dispose() {
    _mapboxMap?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if token is valid
    if (mapboxAccessToken.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Campus Map'),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(context),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: const Center(
          child: Text(
            'Invalid Mapbox access token. Please configure a valid token.',
            style: TextStyle(fontSize: 16, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('mapWidget'),
            onMapCreated: _onMapCreated,
            cameraOptions: _initialCameraPosition,
            styleUri: MapboxStyles.MAPBOX_STREETS, // Use streets-v11
          ),
          if (_isLoadingMap)
            const Center(child: CircularProgressIndicator(color: Colors.blue)),
          if (_mapError != null)
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
                        'Failed to load map: $_mapError',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _mapError = null;
                            _isLoadingMap = true;
                          });
                          _addPolyline();
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

  Future<void> _onMapCreated(MapboxMap controller) async {
    setState(() {
      _mapboxMap = controller;
      _isLoadingMap = true;
    });

    try {
      // Verify access token
      final token = await MapboxOptions.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Mapbox access token is missing or invalid');
      }

      // Set initial camera position
      await _mapboxMap?.setCamera(_initialCameraPosition);

      // Add polyline
      await _addPolyline();
    } catch (e) {
      if (!mounted) return;
      debugPrint('Map initialization error: $e');
      setState(() {
        _isLoadingMap = false;
        _mapError = e.toString();
      });
    }
  }

  Future<void> _addPolyline() async {
    if (_mapboxMap == null || !mounted) {
      setState(() {
        _isLoadingMap = false;
        _mapError = 'Map controller not initialized';
      });
      return;
    }

    try {
      // Remove existing polyline layer and source if present
      if (_polylineLayerId != null) {
        try {
          await _mapboxMap?.style.removeStyleLayer(_polylineLayerId!);
          debugPrint('Removed existing polyline layer: $_polylineLayerId');
        } catch (e) {
          debugPrint('Failed to remove polyline layer $_polylineLayerId: $e');
        }
        try {
          await _mapboxMap?.style.removeStyleSource('polyline-source');
          debugPrint('Removed existing polyline source: polyline-source');
        } catch (e) {
          debugPrint('Failed to remove polyline source: $e');
        }
      }

      // Add polyline source
      final sourceData = {
        'type': 'geojson',
        'data': {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': _polylinePoints.map((p) => [p.lng, p.lat]).toList(),
          },
        },
      };
      await _mapboxMap?.style.addStyleSource(
        'polyline-source',
        jsonEncode(sourceData),
      );
      debugPrint('Added polyline source: polyline-source');

      // Add polyline layer
      _polylineLayerId =
          'polyline-layer-${DateTime.now().millisecondsSinceEpoch}';
      final layerData = {
        'id': _polylineLayerId!,
        'type': 'line',
        'source': 'polyline-source',
        'paint': {
          'line-color': 'rgb(0, 0, 255)', // Blue
          'line-width': 5.0,
          'line-opacity': 0.8,
        },
      };
      await _mapboxMap?.style.addStyleLayer(jsonEncode(layerData), null);
      debugPrint('Polyline layer added: $_polylineLayerId');

      setState(() {
        _isLoadingMap = false;
        _mapError = null;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Polyline error: $e');
      setState(() {
        _isLoadingMap = false;
        _mapError = e.toString();
      });
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: ${e.toString()}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

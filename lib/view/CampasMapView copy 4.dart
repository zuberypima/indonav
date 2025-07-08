import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String? _departmentName;

  @override
  void initState() {
    super.initState();
    // Lock to landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    debugPrint('Screen orientation locked to landscape');

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
    // Restore default orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    debugPrint('Screen orientation restored to default');

    userPositionStream?.cancel();
    mapboxMapController?.dispose();
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
            debugPrint('Back button pressed, navigating to HomePage');
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
              'Distance to Department: ${(_currentPosition != null ? gl.Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, widget.targetLatitude, widget.targetLongitude) / 1000 : widget.distance / 1000).toStringAsFixed(2)} km (approx.)',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
      body:
          widget.targetLatitude.isFinite &&
                  widget.targetLongitude.isFinite &&
                  widget.visitorLatitude.isFinite &&
                  widget.visitorLongitude.isFinite
              ? mp.MapWidget(
                key: const ValueKey('mapWidget'),
                onMapCreated: _onMapCreated,
                styleUri: 'mapbox://styles/mapbox/streets-v12',
              )
              : const Center(
                child: Text(
                  'Invalid coordinates. Please try again.',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ),
    );
  }

  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    setState(() {
      mapboxMapController = controller;
    });

    debugPrint('Map created, initializing markers, labels, and path');

    try {
      // Verify access token
      final token = await mp.MapboxOptions.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Mapbox access token is missing or invalid');
      }
      debugPrint('Access token verified: $token');

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
      debugPrint(
        'Camera set to: lng=${widget.targetLongitude}, lat=${widget.targetLatitude}, zoom=15',
      );

      // Fetch department name from Firestore
      final deptQuery =
          await FirebaseFirestore.instance
              .collection('departments')
              .where('latitude', isEqualTo: widget.targetLatitude.toString())
              .where('longitude', isEqualTo: widget.targetLongitude.toString())
              .limit(1)
              .get();
      if (deptQuery.docs.isNotEmpty) {
        _departmentName =
            deptQuery.docs.first.data()['name'] ?? 'Unknown Department';
        debugPrint('Department name fetched: $_departmentName');
      } else {
        _departmentName = 'Unknown Department';
        debugPrint(
          'No department found for coordinates: (${widget.targetLatitude}, ${widget.targetLongitude})',
        );
      }

      // Add GeoJSON source for text labels
      final labelSource = {
        'type': 'geojson',
        'data': {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [
                  widget.visitorLongitude,
                  widget.visitorLatitude,
                ],
              },
              'properties': {
                'text': 'You are here',
                'color': '#0000FF', // Blue
                'offset': [0.0, -1.5], // Above point
                'anchor': 'bottom',
              },
            },
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [widget.targetLongitude, widget.targetLatitude],
              },
              'properties': {
                'text': _departmentName ?? 'Department',
                'color': '#FF0000', // Red
                'offset': [0.0, 1.5], // Below point
                'anchor': 'top',
              },
            },
          ],
        },
      };
      await mapboxMapController?.style.addStyleSource(
        'label-source',
        jsonEncode(labelSource),
      );
      debugPrint('Added label source: label-source');

      // Add symbol layer for text labels
      final labelLayer = {
        'id': 'label-layer',
        'type': 'symbol',
        'source': 'label-source',
        'layout': {
          'text-field': ['get', 'text'],
          'text-size': 14.0,
          'text-offset': ['get', 'offset'],
          'text-anchor': ['get', 'anchor'],
        },
        'paint': {
          'text-color': ['get', 'color'],
          'text-halo-color': '#FFFFFF',
          'text-halo-width': 2.0,
        },
      };
      await mapboxMapController?.style.addStyleLayer(
        jsonEncode(labelLayer),
        null,
      );
      debugPrint('Added label layer: label-layer');

      // Add visitor marker (approximating Icons.person with pin)
      final visitorAnnotationManager =
          await mapboxMapController?.annotations.createPointAnnotationManager();
      await visitorAnnotationManager?.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(
              widget.visitorLongitude,
              widget.visitorLatitude,
            ),
          ),
          iconImage: 'pin',
          iconSize: 0.3, // Smaller size to suggest a person
        ),
      );
      debugPrint(
        'Added visitor marker (pin) at (${widget.visitorLatitude}, ${widget.visitorLongitude})',
      );

      // Add department marker (approximating Icons.business with marker)
      final departmentAnnotationManager =
          await mapboxMapController?.annotations.createPointAnnotationManager();
      await departmentAnnotationManager?.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(
              widget.targetLongitude,
              widget.targetLatitude,
            ),
          ),
          iconImage: 'marker',
          iconSize: 0.5, // Larger size to suggest a building
        ),
      );
      debugPrint(
        'Added department marker (marker) at (${widget.targetLatitude}, ${widget.targetLongitude})',
      );

      // Add GeoJSON source for path (LineString)
      final initialPathSource = {
        'type': 'geojson',
        'data': {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [widget.visitorLongitude, widget.visitorLatitude],
              [widget.targetLongitude, widget.targetLatitude],
            ],
          },
          'properties': {},
        },
      };
      await mapboxMapController?.style.addStyleSource(
        'path-source',
        jsonEncode(initialPathSource),
      );
      debugPrint('Added initial path source: path-source');

      // Add line layer for path
      final pathLayer = {
        'id': 'path-layer',
        'type': 'line',
        'source': 'path-source',
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': '#00FF00', // Green path
          'line-width': 3.0,
          'line-opacity': 0.8,
        },
      };
      await mapboxMapController?.style.addStyleLayer(
        jsonEncode(pathLayer),
        null,
      );
      debugPrint('Added path layer: path-layer');

      // Update path when visitor location changes
      userPositionStream?.onData((gl.Position position) {
        if (!mounted || mapboxMapController == null) return;
        // Remove existing path source
        mapboxMapController?.style.removeStyleSource('path-source');
        // Add updated path source
        final updatedPathSource = {
          'type': 'geojson',
          'data': {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [position.longitude, position.latitude],
                [widget.targetLongitude, widget.targetLatitude],
              ],
            },
            'properties': {},
          },
        };
        mapboxMapController?.style.addStyleSource(
          'path-source',
          jsonEncode(updatedPathSource),
        );
        setState(() {
          _currentPosition = position;
        });
        debugPrint(
          'Updated path to: visitor (${position.latitude}, ${position.longitude}), department (${widget.targetLatitude}, ${widget.targetLongitude})',
        );
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Map initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Map initialization error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      debugPrint('Location permission granted');
      await _setupPositionTracking();
    } else if (status.isDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission denied'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Location permission denied');
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
      debugPrint('Location permission permanently denied');
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
      debugPrint('Location services disabled');
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

        debugPrint(
          'Current position: lat=${position.latitude}, lng=${position.longitude}',
        );
      },
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        debugPrint('Location error: $e');
      },
    );
  }
}

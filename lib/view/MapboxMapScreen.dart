import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxMapScreen extends StatefulWidget {
  const MapboxMapScreen({super.key});

  @override
  State<MapboxMapScreen> createState() => _MapboxMapScreenState();
}

class _MapboxMapScreenState extends State<MapboxMapScreen> {
  MapboxMap? mapboxMap;
  bool _isMapLoading = true;
  bool _mapInitialized = false;
  String? _errorMessage;
  final String _accessToken =
      "pk.eyJ1IjoicGltYXRlY2giLCJhIjoiY21iYWpvOWRlMDYwajJsc2F5MngwZjJ5aiJ9.ESREiHBRgbEpEuf2qR3rhA";

  @override
  void initState() {
    super.initState();
    _initializeMapbox();
  }

  Future<void> _initializeMapbox() async {
    try {
      // Set the access token before creating the map
      MapboxOptions.setAccessToken(_accessToken);

      setState(() {
        _isMapLoading = false;
      });
    } catch (e) {
      debugPrint("Mapbox initialization failed: $e");
      setState(() {
        _isMapLoading = false;
        _errorMessage = "Failed to initialize map: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mapbox Campus Map")),
      body: Stack(
        children: [
          if (!_isMapLoading && _errorMessage == null)
            MapWidget(
              key: const ValueKey("mapWidget"),
              styleUri: "mapbox://styles/pimatech/cmbajxlw700vo01r4bqbmdrnk",
              onMapCreated: (map) {
                setState(() {
                  mapboxMap = map;
                  _mapInitialized = true;
                });
                _initializeMapPosition();
              },
            ),
          if (_isMapLoading) const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null) Center(child: Text(_errorMessage!)),
          if (!_mapInitialized && !_isMapLoading && _errorMessage == null)
            const Center(child: Text("Map is not initialized")),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mapInitialized ? _moveCamera : null,
        child: const Icon(Icons.add_location),
      ),
    );
  }

  void _initializeMapPosition() {
    try {
      mapboxMap?.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(-8.9416, 33.4171), // longitude, latitude
          ),
          zoom: 15.0,
        ),
      );
    } catch (e) {
      debugPrint("Failed to set initial map position: $e");
      setState(() {
        _errorMessage = "Failed to load map position";
      });
    }
  }

  void _moveCamera() {
    try {
      mapboxMap?.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(-8.9417, 33.4172), // longitude, latitude
          ),
          zoom: 15.0,
        ),
      );
    } catch (e) {
      debugPrint("Failed to move camera: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to move camera")));
    }
  }

  @override
  void dispose() {
    mapboxMap?.dispose();
    super.dispose();
  }
}

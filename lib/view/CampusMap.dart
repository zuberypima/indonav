import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'dart:math';

const String geoJsonString = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "Name": "Administrration Block"
      },
      "geometry": {
        "coordinates": [
          33.416061636424615,
          -8.94159190039862
        ],
        "type": "Point"
      },
      "id": 0
    },
    {
      "type": "Feature",
      "properties": {
        "Name": "Civil & Arch"
      },
      "geometry": {
        "coordinates": [
          33.41572534972457,
          -8.942233877819106
        ],
        "type": "Point"
      },
      "id": 1
    },
    {
      "type": "Feature",
      "properties": {
        "Name": "Dining Hall"
      },
      "geometry": {
        "coordinates": [
          33.417150984394084,
          -8.941837287543322
        ],
        "type": "Point"
      },
      "id": 2
    },
    {
      "type": "Feature",
      "properties": {
        "Name": "Block 6A"
      },
      "geometry": {
        "coordinates": [
          33.41783464918777,
          -8.941567606221057
        ],
        "type": "Point"
      },
      "id": 3
    },
    {
      "type": "Feature",
      "properties": {
        "Name": "Dr Magufuli"
      },
      "geometry": {
        "coordinates": [
          33.419040653142645,
          -8.943273136721189
        ],
        "type": "Point"
      },
      "id": 4
    },
    {
      "type": "Feature",
      "properties": {
        "Name": "Block 6B"
      },
      "geometry": {
        "coordinates": [
          33.41742726825322,
          -8.940988715604632
        ],
        "type": "Point"
      },
      "id": 5
    },
    {
      "type": "Feature",
      "properties": {
        "Name": "Computer Lab 1"
      },
      "geometry": {
        "coordinates": [
          33.415905457236875,
          -8.9417001777541
        ],
        "type": "Point"
      },
      "id": 6
    },
    {
      "type": "Feature",
      "properties": {
        "Name": "Sports Hall"
      },
      "geometry": {
        "coordinates": [
          33.41607994411214,
          -8.942439098995791
        ],
        "type": "Point"
      },
      "id": 7
    },
    {
      "type": "Feature",
      "properties": {
        "Name": "Boundaries"
      },
      "geometry": {
        "coordinates": [
          [
            33.412894146850306,
            -8.939515886306822
          ],
          [
            33.41965705393821,
            -8.939534974184625
          ],
          [
            33.419801973375286,
            -8.943848809017311
          ],
          [
            33.41323229220555,
            -8.943886984318937
          ],
          [
            33.4131936470219,
            -8.944392806684334
          ],
          [
            33.41142562988327,
            -8.9447554713432
          ],
          [
            33.41083629083744,
            -8.943276179017275
          ],
          [
            33.41283617907544,
            -8.942121372442884
          ],
          [
            33.41287482425906,
            -8.939496798426745
          ]
        ],
        "type": "LineString"
      },
      "id": 8
    }
  ]
}
''';

class CampusMap extends StatefulWidget {
  const CampusMap({super.key});

  @override
  State<CampusMap> createState() => _CampusMapState();
}

class _CampusMapState extends State<CampusMap> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadMarkersAndBoundaries();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller?.dispose();
    super.dispose();
  }

  void _loadMarkersAndBoundaries() {
    final geoJson = json.decode(geoJsonString);
    final features = geoJson['features'] as List;

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;

    for (var feature in features) {
      final geometry = feature['geometry'];
      if (geometry['type'] == 'Point') {
        final coordinates = geometry['coordinates'] as List<dynamic>;
        final longitude = coordinates[0] as double;
        final latitude = coordinates[1] as double;
        final properties = feature['properties'] as Map<String, dynamic>;
        final name = properties['Name'] as String;

        final marker = Marker(
          markerId: MarkerId('point_${features.indexOf(feature)}'),
          position: LatLng(latitude, longitude),
          infoWindow: InfoWindow(title: name),
        );
        _markers.add(marker);

        minLat = min(minLat, latitude);
        maxLat = max(maxLat, latitude);
        minLng = min(minLng, longitude);
        maxLng = max(maxLng, longitude);
      } else if (geometry['type'] == 'LineString' &&
          feature['properties']['Name'] == 'Boundaries') {
        final coordinates = geometry['coordinates'];
        if (coordinates is List<dynamic>) {
          final boundaryPoints = <LatLng>[];
          for (var coord in coordinates) {
            if (coord is List<dynamic> && coord.length >= 2) {
              final longitude = coord[0] as double;
              final latitude = coord[1] as double;
              boundaryPoints.add(LatLng(latitude, longitude));
              minLat = min(minLat, latitude);
              maxLat = max(maxLat, latitude);
              minLng = min(minLng, longitude);
              maxLng = max(maxLng, longitude);
            }
          }
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('boundary'),
              points: boundaryPoints,
              color: Colors.red,
              width: 2,
            ),
          );
        }
      }
    }

    // Adjust camera to fit all markers and boundaries with dynamic padding
    if (_controller != null && mounted) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final padding =
          min(screenWidth, screenHeight) * 0.1; // 10% of the smaller dimension
      _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          padding, // Dynamic padding based on screen size
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map with Boundaries'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: GoogleMap(
        onMapCreated: (controller) {
          _controller = controller;
          _loadMarkersAndBoundaries();
        },
        initialCameraPosition: const CameraPosition(
          target: LatLng(-8.9416, 33.4171), // Approximate center
          zoom: 100,
        ),
        markers: _markers,
        polylines: _polylines,
        mapType: MapType.normal,
      ),
    );
  }
}

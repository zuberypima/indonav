import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:indonav/view/QRScannerPage.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';

class CampasMapView extends StatefulWidget {
  final double targetLatitude;
  final double targetLongitude;

  const CampasMapView({
    super.key,
    required this.targetLatitude,
    required this.targetLongitude,
  });

  @override
  State<CampasMapView> createState() => _CampasMapViewState();
}

class _CampasMapViewState extends State<CampasMapView> {
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navigate back to QRScannerPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const QRScannerPage()),
        );
        return false; // Prevent default pop
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Campus Map'),
          centerTitle: true,
          backgroundColor: Colors.deepOrange,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const QRScannerPage()),
              );
            },
          ),
        ),
        body: mp.MapWidget(
          onMapCreated: _onMapCreated,
          styleUri: 'mapbox://styles/pimatech/cmbajxlw700vo01r4bqbmdrnk',
        ),
      ),
    );
  }

  void _onMapCreated(mp.MapboxMap controller) {
    setState(() {
      mapboxMapController = controller;
    });

    // Enable user location
    mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    // Center map on target coordinates
    mapboxMapController?.setCamera(
      mp.CameraOptions(
        zoom: 15,
        center: mp.Point(
          coordinates: mp.Position(
            widget.targetLongitude,
            widget.targetLatitude,
          ),
        ),
      ),
    );

    // Add marker for department
    mapboxMapController?.annotations.createPointAnnotationManager().then((
      manager,
    ) {
      manager.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(
              widget.targetLongitude,
              widget.targetLatitude,
            ),
          ),
          iconImage: 'pin-icon',
          iconSize: 0.5,
        ),
      );
    });
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _setupPositionTracking();
    } else if (status.isDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission denied'),
          backgroundColor: Colors.red,
        ),
      );
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

        mapboxMapController?.location.updateSettings(
          mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
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
      },
    );
  }
}

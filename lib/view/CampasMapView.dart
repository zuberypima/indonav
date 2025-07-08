import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _googleMapController;
  StreamSubscription<gl.Position>? userPositionStream;
  gl.Position? _currentPosition;
  String? _departmentName;
  Set<Marker> _markers = {};
  Polyline? _path;

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
    _googleMapController?.dispose();
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
      body: widget.targetLatitude.isFinite &&
              widget.targetLongitude.isFinite &&
              widget.visitorLatitude.isFinite &&
              widget.visitorLongitude.isFinite
          ? GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.targetLatitude, widget.targetLongitude),
                zoom: 15,
              ),
              markers: _markers,
              polylines: _path != null ? {_path!} : <Polyline>{},
              mapType: MapType.normal,
            )
          : const Center(
              child: Text(
                'Invalid coordinates. Please try again.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    setState(() {
      _googleMapController = controller;
    });

    debugPrint('Map created, initializing markers and path');

    try {
      // Fetch department name from Firestore
      final deptQuery = await FirebaseFirestore.instance
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

      // Validate coordinates before adding markers
      if (!widget.visitorLatitude.isFinite ||
          !widget.visitorLongitude.isFinite ||
          !widget.targetLatitude.isFinite ||
          !widget.targetLongitude.isFinite) {
        debugPrint('Invalid coordinates detected');
        return;
      }

      // Add visitor marker
      _markers.add(
        Marker(
          markerId: const MarkerId('visitor'),
          position: LatLng(widget.visitorLatitude, widget.visitorLongitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
      );
      debugPrint(
        'Added visitor marker at (${widget.visitorLatitude}, ${widget.visitorLongitude})',
      );

      // Add department marker
      _markers.add(
        Marker(
          markerId: const MarkerId('department'),
          position: LatLng(widget.targetLatitude, widget.targetLongitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _departmentName ?? 'Department'),
        ),
      );
      debugPrint(
        'Added department marker at (${widget.targetLatitude}, ${widget.targetLongitude})',
      );

      // Add initial path
      _path = Polyline(
        polylineId: const PolylineId('path'),
        points: [
          LatLng(widget.visitorLatitude, widget.visitorLongitude),
          LatLng(widget.targetLatitude, widget.targetLongitude),
        ],
        color: Colors.green,
        width: 3,
      );
      setState(() {});

      // Update path when visitor location changes
      userPositionStream?.onData((gl.Position position) {
        if (!mounted || _googleMapController == null) return;
        setState(() {
          _currentPosition = position;
          _markers.removeWhere((marker) => marker.markerId.value == 'visitor');
          _markers.add(
            Marker(
              markerId: const MarkerId('visitor'),
              position: LatLng(position.latitude, position.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'You are here'),
            ),
          );
          _path = Polyline(
            polylineId: const PolylineId('path'),
            points: [
              LatLng(position.latitude, position.longitude),
              LatLng(widget.targetLatitude, widget.targetLongitude),
            ],
            color: Colors.green,
            width: 3,
          );
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
        if (!mounted || _googleMapController == null) return;

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
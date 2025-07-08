import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:indonav/view/HomePage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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

    try {
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
      } else {
        _departmentName = 'Unknown Department';
      }

      // Add markers
      _markers.add(
        Marker(
          markerId: const MarkerId('visitor'),
          position: LatLng(widget.visitorLatitude, widget.visitorLongitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('department'),
          position: LatLng(widget.targetLatitude, widget.targetLongitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _departmentName ?? 'Department'),
        ),
      );

      // Fetch initial directions
      final origin = LatLng(widget.visitorLatitude, widget.visitorLongitude);
      final destination = LatLng(widget.targetLatitude, widget.targetLongitude);
      final points = await fetchDirections(origin, destination);
      if (points.isNotEmpty) {
        _path = Polyline(
          polylineId: const PolylineId('path'),
          points: points,
          color: Colors.green,
          width: 3,
        );
        setState(() {});
      }

      // Update path dynamically
      userPositionStream?.onData((gl.Position position) {
        if (!mounted || _googleMapController == null) return;
        setState(() {
          _currentPosition = position;
          _markers.removeWhere((marker) => marker.markerId.value == 'visitor');
          _markers.add(
            Marker(
              markerId: const MarkerId('visitor'),
              position: LatLng(position.latitude, position.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
              infoWindow: const InfoWindow(title: 'You are here'),
            ),
          );
        });

        fetchDirections(
          LatLng(position.latitude, position.longitude),
          destination,
        ).then((newPoints) {
          if (newPoints.isNotEmpty) {
            setState(() {
              _path = Polyline(
                polylineId: const PolylineId('path'),
                points: newPoints,
                color: Colors.green,
                width: 3,
              );
            });
          }
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Map initialization error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<LatLng>> fetchDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // Replace with your API key
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routes = data['routes'] as List;
      if (routes.isNotEmpty) {
        final points = routes[0]['overview_polyline']['points'];
        return decodePolyline(points);
      }
    }
    return [];
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await _setupPositionTracking();
    } else if (status.isPermanentlyDenied) {
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
    ).listen((gl.Position position) {
      if (!mounted || _googleMapController == null) return;
      setState(() {
        _currentPosition = position;
      });
    });
  }
}

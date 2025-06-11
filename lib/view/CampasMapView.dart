import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

class CampasMapView extends StatefulWidget {
  const CampasMapView({super.key});

  @override
  State<CampasMapView> createState() => _CampasMapViewState();
}

class _CampasMapViewState extends State<CampasMapView> {
  mp.MapboxMap? mapboxMapController;

  StreamSubscription? userPositionStream;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _setupPositionTracking();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    userPositionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: mp.MapWidget(
        onMapCreated: _onMapCreated,
        styleUri: 'mapbox://styles/pimatech/cmbajxlw700vo01r4bqbmdrnk',
        // mp.MapboxStyles.MAPBOX_STREETS,
      ),
    );
  }

  void _onMapCreated(mp.MapboxMap controller) {
    setState(() {
      mapboxMapController = controller;
    });

    mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
  }

  Future<void> _setupPositionTracking() async {
    bool serviceEnabled;
    gl.LocationPermission permission;

    serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return Future.error('Location services are disabled');
    }
    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        return Future.error('Location services are disabled');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error(
        'Location permisions are permanent denaide, we cannot request  permision',
      );
    }

    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((gl.Position? position) {
      if (position != null && mapboxMapController != null) {
        mapboxMapController?.setCamera(
          mp.CameraOptions(
            zoom: 15,

            center: mp.Point(
              coordinates: mp.Position(
                33.416138,
                -8.941800,
                //  position.latitude
              ),
            ),
          ),
        );
      }
    });
  }
}

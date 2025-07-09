// import 'dart:developer' as dev;

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:math';

// const String geoJsonString = '''
// {
//   "type": "FeatureCollection",
//   "features": [
//     {
//       "type": "Feature",
//       "properties": {
//         "Name": "Administrration Block"
//       },
//       "geometry": {
//         "coordinates": [
//           33.416061636424615,
//           -8.94159190039862
//         ],
//         "type": "Point"
//       },
//       "id": 0
//     },
//     {
//       "type": "Feature",
//       "properties": {
//         "Name": "Civil & Arch"
//       },
//       "geometry": {
//         "coordinates": [
//           33.41572534972457,
//           -8.942233877819106
//         ],
//         "type": "Point"
//       },
//       "id": 1
//     },
//     {
//       "type": "Feature",
//       "properties": {
//         "Name": "Dining Hall"
//       },
//       "geometry": {
//         "coordinates": [
//           33.417150984394084,
//           -8.941837287543322
//         ],
//         "type": "Point"
//       },
//       "id": 2
//     },
//     {
//       "type": "Feature",
//       "properties": {
//         "Name": "Block 6A"
//       },
//       "geometry": {
//         "coordinates": [
//           33.41783464918777,
//           -8.941567606221057
//         ],
//         "type": "Point"
//       },
//       "id": 3
//     },
//     {
//       "type": "Feature",
//       "properties": {
//         "Name": "Dr Magufuli"
//       },
//       "geometry": {
//         "coordinates": [
//           33.419040653142645,
//           -8.943273136721189
//         ],
//         "type": "Point"
//       },
//       "id": 4
//     },
//     {
//       "type": "Feature",
//       "properties": {
//         "Name": "Block 6B"
//       },
//       "geometry": {
//         "coordinates": [
//           33.41742726825322,
//           -8.940988715604632
//         ],
//         "type": "Point"
//       },
//       "id": 5
//     },
//     {
//       "type": "Feature",
//       "properties": {
//         "Name": "Computer Lab 1"
//       },
//       "geometry": {
//         "coordinates": [
//           33.415905457236875,
//           -8.9417001777541
//         ],
//         "type": "Point"
//       },
//       "id": 6
//     },
//     {
//       "type": "Feature",
//       "properties": {
//         "Name": "Sports Hall"
//       },
//       "geometry": {
//         "coordinates": [
//           33.41607994411214,
//           -8.942439098995791
//         ],
//         "type": "Point"
//       },
//       "id": 7
//     }
//   ]
// }
// ''';

// class CampusMap extends StatefulWidget {
//   const CampusMap({super.key});

//   @override
//   State<CampusMap> createState() => _CampusMapState();
// }

// class _CampusMapState extends State<CampusMap> {
//   GoogleMapController? _controller;
//   Set<Marker> _markers = {};
//   Set<Polyline> _polylines = {};

//   @override
//   void initState() {
//     super.initState();
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     _loadMarkersAndRoute();
//   }

//   @override
//   void dispose() {
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     _controller?.dispose();
//     super.dispose();
//   }

//   Future<void> _loadMarkersAndRoute() async {
//     final geoJson = json.decode(geoJsonString);
//     final features = geoJson['features'] as List;

//     for (var feature in features) {
//       final geometry = feature['geometry'];
//       if (geometry['type'] == 'Point') {
//         final coordinates = geometry['coordinates'] as List<dynamic>;
//         final longitude = coordinates[0] as double;
//         final latitude = coordinates[1] as double;
//         final properties = feature['properties'] as Map<String, dynamic>;
//         final name = properties['Name'] as String;

//         final marker = Marker(
//           markerId: MarkerId('point_${features.indexOf(feature)}'),
//           position: LatLng(latitude, longitude),
//           infoWindow: InfoWindow(title: name),
//         );
//         _markers.add(marker);
//       }
//     }

//     // Hardcode coordinates for Sports Hall and Block 6A
//     final sportsHall =
//         features.firstWhere(
//               (f) => f['properties']['Name'] == 'Sports Hall',
//             )['geometry']['coordinates']
//             as List<dynamic>;
//     final block6A =
//         features.firstWhere(
//               (f) => f['properties']['Name'] == 'Block 6A',
//             )['geometry']['coordinates']
//             as List<dynamic>;
//     final origin = LatLng(sportsHall[1] as double, sportsHall[0] as double);
//     final destination = LatLng(block6A[1] as double, block6A[0] as double);

//     // Wait for map to initialize
//     await Future.delayed(const Duration(seconds: 1));

//     const apiKey =
//         'AIzaSyBOpRefK-45E8lUfGUaicXtSklxLA-XWaY'; // Replace with your API key
//     final url =
//         'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey';

//     try {
//       final response = await http.get(Uri.parse(url));
//       dev.log('API Response: ${response.statusCode} - ${response.body}');
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         final routes = data['routes'] as List;
//         if (routes.isNotEmpty) {
//           final points = routes[0]['overview_polyline']['points'];
//           final decodedPoints = _decodePolyline(points);
//           if (decodedPoints.isNotEmpty) {
//             if (mounted) {
//               setState(() {
//                 _polylines = {
//                   Polyline(
//                     polylineId: const PolylineId('route'),
//                     points: decodedPoints,
//                     color: Colors.blue,
//                     width: 5,
//                   ),
//                 };
//               });
//               // Adjust camera to fit the route
//               final latitudes = decodedPoints.map((p) => p.latitude).toList();
//               final longitudes = decodedPoints.map((p) => p.longitude).toList();
//               final southwest = LatLng(
//                 latitudes.reduce(min),
//                 longitudes.reduce(min),
//               );
//               final northeast = LatLng(
//                 latitudes.reduce(max),
//                 longitudes.reduce(max),
//               );
//               _controller?.animateCamera(
//                 CameraUpdate.newLatLngBounds(
//                   LatLngBounds(southwest: southwest, northeast: northeast),
//                   50, // Padding
//                 ),
//               );
//             }
//           } else {
//             dev.log('No points in decoded polyline');
//           }
//         } else {
//           dev.log('No routes in response');
//         }
//       } else {
//         dev.log('API Error: ${response.statusCode} - ${response.body}');
//       }
//     } catch (e) {
//       dev.log('API Request Error: $e');
//     }
//   }

//   List<LatLng> _decodePolyline(String encoded) {
//     List<LatLng> points = [];
//     int index = 0, len = encoded.length;
//     int lat = 0, lng = 0;

//     while (index < len) {
//       int b, shift = 0, result = 0;
//       do {
//         b = encoded.codeUnitAt(index++) - 63;
//         result |= (b & 0x1f) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
//       lat += dlat;

//       shift = 0;
//       result = 0;
//       do {
//         b = encoded.codeUnitAt(index++) - 63;
//         result |= (b & 0x1f) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
//       lng += dlng;

//       points.add(LatLng(lat / 1E5, lng / 1E5));
//     }
//     return points;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Campus Map: Sports Hall to Block 6A'),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//       ),
//       body: GoogleMap(
//         onMapCreated: (controller) {
//           _controller = controller;
//           // Trigger route load after map is created
//           _loadMarkersAndRoute();
//         },
//         initialCameraPosition: const CameraPosition(
//           target: LatLng(-8.9416, 33.4171), // Approximate center
//           zoom: 15,
//         ),
//         markers: _markers,
//         polylines: _polylines,
//         mapType: MapType.normal,
//       ),
//     );
//   }
// }

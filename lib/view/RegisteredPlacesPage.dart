// import 'package:flutter/material.dart';
// import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// class RegisteredPlacesPage extends StatefulWidget {
//   const RegisteredPlacesPage({super.key});

//   @override
//   State<RegisteredPlacesPage> createState() => _RegisteredPlacesPageState();
// }

// class _RegisteredPlacesPageState extends State<RegisteredPlacesPage> {
//   MapboxMap? mapboxMap;
//   bool _mapInitialized = false;
//   String? _errorMessage;
//   PointAnnotationManager? _pointAnnotationManager;

//   final String _accessToken = 
//       "pk.eyJ1IjoicGltYXRlY2giLCJhIjoiY21iYWpvOWRlMDYwajJsc2F5MngwZjJ5aiJ9.ESREiHBRgbEpEuf2qR3rhA";

//   final List<Map<String, dynamic>> _places = [
//     {'title': 'Venues', 'icon': Icons.meeting_room, 'color': Colors.blue, 'lng': -8.9416, 'lat': 33.4171},
//     {'title': 'Offices', 'icon': Icons.business, 'color': Colors.green, 'lng': -8.9417, 'lat': 33.4172},
//     {'title': 'Departments', 'icon': Icons.school, 'color': Colors.orange, 'lng': -8.9418, 'lat': 33.4173},
//     {'title': 'Hostels', 'icon': Icons.hotel, 'color': Colors.purple, 'lng': -8.9419, 'lat': 33.4174},
//     {'title': 'Libraries', 'icon': Icons.local_library, 'color': Colors.teal, 'lng': -8.9420, 'lat': 33.4175},
//   ];

//   @override
//   void initState() {
//     super.initState();
//     MapboxOptions.setAccessToken(_accessToken);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('MustNav Places'),
//       ),
//       body: Column(
//         children: [
//           // Places grid view
//           SizedBox(
//             height: 180,
//             child: GridView.builder(
//               padding: const EdgeInsets.all(12.0),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 12,
//                 mainAxisSpacing: 12,
//                 childAspectRatio: 1,
//               ),
//               itemCount: _places.length,
//               itemBuilder: (context, index) {
//                 final place = _places[index];
//                 return GestureDetector(
//                   onTap: () => _moveCameraToLocation(place['lng'], place['lat']),
//                   child: Card(
//                     color: (place['color'] as Color).withOpacity(0.8),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     elevation: 4,
//                     child: Center(
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             place['icon'] as IconData,
//                             size: 48,
//                             color: Colors.white,
//                           ),
//                           const SizedBox(height: 10),
//                           Text(
//                             place['title'] as String,
//                             style: const TextStyle(
//                               fontSize: 18,
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           // Map view
//           Expanded(
//             child: Stack(
//               children: [
//                 MapWidget(
//                   key: const ValueKey("mapWidget"),
//                   styleUri: "mapbox://styles/pimatech/cmbajxlw700vo01r4bqbmdrnk",
//                   onMapCreated: (map) {
//                     mapboxMap = map;
//                     _initializeMap();
//                   },
//                 ),
//                 if (_errorMessage != null)
//                   Center(child: Text(_errorMessage!, 
//                       style: const TextStyle(color: Colors.red, fontSize: 16))),
//                 if (!_mapInitialized && _errorMessage == null)
//                   const Center(child: CircularProgressIndicator()),
//               ],
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _mapInitialized ? _moveCamera : null,
//         child: const Icon(Icons.add_location),
//       ),
//     );
//   }

//   Future<void> _initializeMap() async {
//     try {
//       // Initialize camera position
//       await mapboxMap?.setCamera(CameraOptions(
//         center: Point(coordinates: Position(-8.9416, 33.4171)),
//         zoom: 15.0,
//       ));

//       // Initialize annotation manager
//       _pointAnnotationManager = await mapboxMap?.annotations.createPointAnnotationManager();

//       // Add markers
//       await _addPlaceMarkers();

//       setState(() => _mapInitialized = true);
//     } catch (e) {
//       debugPrint("Map initialization error: $e");
//       setState(() => _errorMessage = "Failed to initialize map");
//     }
//   }

//   Future<void> _addPlaceMarkers() async {
//     try {
//       // Clear existing annotations
//       await _pointAnnotationManager?.deleteAll();

//       // Add new markers
//       for (final place in _places) {
//         await _pointAnnotationManager?.create(PointAnnotationOptions(
//           geometry: Point(
//             coordinates: Position(place['lng'], place['lat']),
//           ).toJson(),
//           iconImage: _getIconNameForPlace(place['title']),
//           iconSize: 1.0,
//         ));
//       }
//     } catch (e) {
//       debugPrint("Error adding markers: $e");
//     }
//   }

//   String _getIconNameForPlace(String title) {
//     switch (title) {
//       case 'Venues': return 'venue-icon';
//       case 'Offices': return 'office-icon';
//       case 'Departments': return 'department-icon';
//       case 'Hostels': return 'hostel-icon';
//       case 'Libraries': return 'library-icon';
//       default: return 'default-marker';
//     }
//   }

//   void _moveCameraToLocation(double lng, double lat) {
//     try {
//       mapboxMap?.setCamera(CameraOptions(
//         center: Point(coordinates: Position(lng, lat)),
//         zoom: 15.0,
//       ));
//     } catch (e) {
//       debugPrint("Camera move error: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Failed to move camera")),
//       );
//     }
//   }

//   void _moveCamera() {
//     _moveCameraToLocation(-8.9417, 33.4172);
//   }

//   @override
//   void dispose() {
//     _pointAnnotationManager?.deleteAll();
//     mapboxMap?.dispose();
//     super.dispose();
//   }
// }
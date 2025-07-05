// import 'package:flutter/material.dart';
// import 'package:indonav/constants.dart';
// import 'package:woosmap_flutter/woosmap_flutter.dart';

// class CampusMapScreen extends StatefulWidget {
//   const CampusMapScreen({super.key});

//   @override
//   State<CampusMapScreen> createState() => _CampusMapScreenState();
// }

// class _CampusMapScreenState extends State<CampusMapScreen> {
//   WoosmapController? _controller;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Campus Outdoor Map")),
//       body: SafeArea(
//         child: WoosmapMapViewWidget(
//           wooskey: AppConstants.of(context)?.privateKeyAndroid ?? "",
//           onRef: (controller) async {
//             _controller = controller;
//             // No setCenter needed; rely on mapOptions for initial view
//           },
//           mapOptions: {
//             "zoom": 15.0, // Adjusted zoom for wider area
//             "center": {"lat": -8.9416, "lng": 33.4171}, // Calculated center
//             "controls": {"zoom": true},
//             "scrollWheel": true,
//           },
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           if (_controller != null) {
//             addMarker(
//               LatLng(lat: -8.9417, lng: 33.4172),
//             ); // Example marker near center
//           }
//         },
//         child: const Icon(Icons.add_location),
//       ),
//     );
//   }

//   void addMarker(LatLng position) {
//     if (_controller != null) {
//       final marker = Marker.create(
//         MarkerOptions(position: position),
//         _controller!,
//         click: (value) => debugPrint("Marker clicked at $position"),
//       );
//       _controller?.addMarker(marker);
//     }
//   }

//   void calculateRoute(LatLng start, LatLng end) {
//     if (_controller != null) {
//       _controller
//           ?.directions(
//             DirectionRequest(
//                   origin: start,
//                   destination: end,
//                   travelMode: TravelMode.walking,
//                 )
//                 as IndoorDirectionRequest,
//           )
//           .then((route) {
//             _controller?.setDirections(route);
//           });
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       addMarker(LatLng(lat: -8.9416, lng: 33.4171)); // Center POI
//       calculateRoute(
//         LatLng(lat: -8.9416, lng: 33.4171),
//         LatLng(lat: -8.9417, lng: 33.4172),
//       ); // Example route
//     });
//   }

//   @override
//   void dispose() {
//     _controller;
//     super.dispose();
//   }
// }

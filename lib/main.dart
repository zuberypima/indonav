import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:indonav/view/CampasMapView.dart';
import 'package:indonav/view/HomePage.dart';
import 'package:indonav/view/PointsMaps.dart';
import 'package:indonav/view/VisitorHomePage.dart';
import 'package:indonav/view/VisitorRegistrationPage.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  MapboxOptions.setAccessToken(
    'pk.eyJ1IjoicGltYXRlY2giLCJhIjoiY21iYWpvOWRlMDYwajJsc2F5MngwZjJ5aiJ9.ESREiHBRgbEpEuf2qR3rhA',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home:
          //  VisitorRegistrationPage(),
          //  Pointsmaps(),
          // CampasMapView(),
          HomePage(),
      // VisitorHomePage(),
    );
  }
}

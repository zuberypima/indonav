import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:indonav/view/CampasMapView.dart';
import 'package:indonav/view/CampusMapScreen.dart';
import 'package:indonav/view/HomePage.dart';
import 'package:indonav/view/MapboxMapScreen.dart';
import 'package:indonav/view/PointsMaps.dart';
import 'package:indonav/view/RegistrationPage.dart';
import 'package:indonav/view/VisitorHomePage.dart';
import 'package:indonav/view/VisitorRegistrationPage.dart';
import 'package:indonav/view/loginpage.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  MapboxOptions.setAccessToken(
    // 'pk.eyJ1IjoicGltYXRlY2giLCJhIjoiY21iYWpvOWRlMDYwajJsc2F5MngwZjJ5aiJ9.ESREiHBRgbEpEuf2qR3rhA',
    'pk.eyJ1IjoicGltYXRlY2giLCJhIjoiY21jbWc0YWRtMDI1bTJpc2VzNzF5djBucyJ9.vHTjfBLCIYT7opZOHkXqAg',
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
      // LoginPage(),
      // RegistrationPage(),
      // MapboxMapScreen(),
      // CampusMapScreen(),
      //  VisitorRegistrationPage(),
      //  Pointsmaps(),
      // CampasMapView(),
      HomePage(visitorName: ''),
      // VisitorHomePage(),
    );
  }
}

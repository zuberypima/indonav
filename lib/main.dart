import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:indonav/view/CampasMapView.dart';
import 'package:indonav/view/CampusMapScreen.dart';
import 'package:indonav/view/CampusViewPage.dart';
import 'package:indonav/view/HomePage.dart';
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
    // 'pk.eyJ1IjoicGltYXRlY2giLCJhIjoiY21jbWc0YWRtMDI1bTJpc2VzNzF5djBucyJ9.vHTjfBLCIYT7opZOHkXqAg',
    'AIzaSyBOpRefK-45E8lUfGUaicXtSklxLA-XWaY',
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
      home: FutureBuilder(
        future: Firebase.initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                if (authSnapshot.connectionState == ConnectionState.active) {
                  final User? user = authSnapshot.data;
                  if (user != null) {
                    // User is signed in, navigate to VisitorHomePage
                    return HomePage(visitorName: '');
                  } else {
                    // User is not signed in, navigate to LoginPage
                    return LoginPage();
                  }
                }
                // Show loading while checking auth state
                return const Center(child: CircularProgressIndicator());
              },
            );
          }
          // Show loading while Firebase initializes
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

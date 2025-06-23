import 'package:flutter/material.dart';
import 'package:indonav/view/CampasMapView.dart';
import 'package:indonav/view/QRScannerPage.dart';
import 'package:indonav/view/VisitorRegistrationPage.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Exit App'),
                    content: const Text('Are you sure you want to exit?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
            ) ??
            false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Indonav Visitor'),
          centerTitle: true,
          backgroundColor: Colors.deepOrange,
        ),
        body: Container(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map, size: 80, color: Colors.deepOrange),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to Indonav',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Navigate campus with ease',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildNavButton(
                    context,
                    icon: Icons.qr_code_scanner,
                    title: 'Scan QR Code',
                    subtitle: 'Scan department QR to register',
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRScannerPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNavButton(
                    context,
                    icon: Icons.person_add,
                    title: 'Register Visitor',
                    subtitle: 'Manually register a visitor',
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VisitorRegistrationPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNavButton(
                    context,
                    icon: Icons.map_outlined,
                    title: 'Campus Map',
                    subtitle: 'View campus layout',
                    onPressed: () {
                      // Navigator.pushReplacement(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder:
                      //         (context) =>  CampasMapView(
                      //           targetLatitude: 33.416138,
                      //           targetLongitude: -8.941800,
                      //         ),
                      //   ),
                      // );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.deepOrange),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

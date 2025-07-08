import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:indonav/view/RegistrationPage.dart';
import 'package:indonav/view/HomePage.dart';
import 'package:permission_handler/permission_handler.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getVisitorLocation() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        throw Exception(
          'Location permission permanently denied. Please enable in settings.',
        );
      }
      throw Exception('Location permission denied');
    }

    if (!await gl.Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services disabled');
    }

    final position = await gl.Geolocator.getCurrentPosition(
      desiredAccuracy: gl.LocationAccuracy.high,
    );

    if (position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      throw Exception(
        'Invalid visitor coordinates: (${position.latitude}, ${position.longitude})',
      );
    }

    debugPrint(
      'Visitor position: lat=${position.latitude}, lng=${position.longitude}',
    );
    return {'latitude': position.latitude, 'longitude': position.longitude};
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      debugPrint('Starting login submission');

      // Sign in with Firebase Authentication
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final userId = credential.user?.uid;

      if (userId == null) {
        throw Exception('Failed to sign in user');
      }

      // Fetch visitor's location
      final visitorLocation = await _getVisitorLocation();
      final visitorLat = visitorLocation['latitude'] as double;
      final visitorLng = visitorLocation['longitude'] as double;

      // Save check-in record to Firestore
      await FirebaseFirestore.instance.collection('visitor_registrations').add({
        'email': _emailController.text,
        'visitorLatitude': visitorLat,
        'visitorLongitude': visitorLng,
        'userId': userId,
        'checkInTime': Timestamp.now(),
        'checkOutTime': null,
      });

      debugPrint('Login and check-in saved successfully for user: $userId');

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      setState(() {
        _emailController.clear();
        _passwordController.clear();
        _isSubmitting = false;
      });

      // Navigate to HomePage
      debugPrint('Navigating to HomePage');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(visitorName: '')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      String errorMsg;
      if (e.toString().contains('permission')) {
        errorMsg = 'Location permission issue. Please enable in settings.';
        if (e.toString().contains('permanently denied')) {
          await openAppSettings(); // Prompt user to open settings
        }
      } else if (e.toString().contains('coordinates')) {
        errorMsg = 'Invalid location data. Please try again.';
      } else if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMsg = 'No user found for that email.';
            break;
          case 'wrong-password':
            errorMsg = 'Incorrect password.';
            break;
          case 'invalid-email':
            errorMsg = 'The email address is invalid.';
            break;
          case 'user-disabled':
            errorMsg = 'This user account has been disabled.';
            break;
          default:
            errorMsg = 'Login failed: ${e.message}';
        }
      } else {
        errorMsg = 'Failed to submit: ${e.toString()}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
      debugPrint('Login error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('MustNav Login'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        leading:
            Navigator.canPop(context)
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    debugPrint(
                      'Back button pressed, navigating to previous page',
                    );
                    Navigator.pop(context);
                  },
                )
                : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepOrange.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Please sign in to continue',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value!.isEmpty) return 'Email is required';
                              if (!EmailValidator.validate(value))
                                return 'Enter a valid email';
                              return null;
                            },
                            onFieldSubmitted:
                                (_) => FocusScope.of(context).nextFocus(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value!.isEmpty) return 'Password is required';
                              return null;
                            },
                            onFieldSubmitted:
                                (_) => FocusScope.of(context).unfocus(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          shadowColor: Colors.deepOrange.withOpacity(0.4),
                        ),
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                                : const Text(
                                  'SIGN IN',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        debugPrint('Sign Up button pressed');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegistrationPage(),
                          ),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Don\'t have an account? ',
                          style: TextStyle(color: Colors.grey),
                          children: [
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

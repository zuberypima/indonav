import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:indonav/view/CampasMapView.dart';
import 'package:indonav/view/HomePage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class VisitorRegistrationPage extends StatefulWidget {
  final Map<String, dynamic>? scannedDepartment;

  const VisitorRegistrationPage({super.key, this.scannedDepartment});

  @override
  _VisitorRegistrationPageState createState() =>
      _VisitorRegistrationPageState();
}

class _VisitorRegistrationPageState extends State<VisitorRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _purposeController = TextEditingController();
  final _hostController = TextEditingController();
  String? _selectedDepartmentId;
  String? _selectedDepartmentName;
  String? _selectedHostId;
  bool _isSubmitting = false;
  bool _useManualHost = false;
  DateTime? _registrationDate;

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _registrationDate =
        DateTime.now(); // Auto-set to current time (11:33 PM EAT, July 08, 2025)
    _fetchUserDetails();
    if (widget.scannedDepartment != null) {
      _selectedDepartmentId = widget.scannedDepartment!['departmentId'];
      _selectedDepartmentName = widget.scannedDepartment!['name'];
      print('Scanned department: ${widget.scannedDepartment}');
    }
  }

  Future<void> _fetchUserDetails() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final email = user.email;
        if (email != null) {
          final userDoc =
              await _firestore
                  .collection('users')
                  .where('email', isEqualTo: email)
                  .limit(1)
                  .get();
          if (userDoc.docs.isNotEmpty) {
            final userData = userDoc.docs.first.data() as Map<String, dynamic>;
            setState(() {
              _emailController.text = userData['email'] ?? email;
              _nameController.text = userData['visitorName'] ?? 'Unknown User';
            });
          } else {
            setState(() {
              _emailController.text = email;
              _nameController.text = 'Unknown User';
            });
          }
        }
      } else {
        setState(() {
          _nameController.text = 'Guest User';
          _emailController.text = 'guest@example.com';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to use your details.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _nameController.text = 'Guest User';
        _emailController.text = 'guest@example.com';
      });
      print('Error fetching user details: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _purposeController.dispose();
    _hostController.dispose();
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

    print(
      'Visitor position: lat=${position.latitude}, lng=${position.longitude}',
    );
    return {'latitude': position.latitude, 'longitude': position.longitude};
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      print(
        'Starting registration submission for department: $_selectedDepartmentId',
      );

      // Fetch visitor's location
      final visitorLocation = await _getVisitorLocation();
      final visitorLat = visitorLocation['latitude'] as double;
      final visitorLng = visitorLocation['longitude'] as double;

      // Fetch department coordinates from Firestore
      double? deptLat, deptLng;
      final deptDoc =
          await _firestore
              .collection('departments')
              .doc(_selectedDepartmentId)
              .get();
      if (!deptDoc.exists) {
        throw Exception('Department not found: $_selectedDepartmentId');
      }
      final deptData = deptDoc.data()!;
      deptLat = double.tryParse(deptData['latitude']?.toString() ?? '');
      deptLng = double.tryParse(deptData['longitude']?.toString() ?? '');

      // Validate department coordinates
      if (deptLat == null ||
          deptLng == null ||
          !deptLat.isFinite ||
          !deptLng.isFinite) {
        throw Exception('Invalid department coordinates: ($deptLat, $deptLng)');
      }
      if (deptLat < -90 || deptLat > 90 || deptLng < -180 || deptLng > 180) {
        throw Exception(
          'Department coordinates out of range: ($deptLat, $deptLng)',
        );
      }

      print('Department coordinates: lat=$deptLat, lng=$deptLng');

      // Calculate distance
      final distance = gl.Geolocator.distanceBetween(
        visitorLat,
        visitorLng,
        deptLat,
        deptLng,
      );
      print(
        'Distance to department: ${(distance / 1000).toStringAsFixed(2)} km',
      );

      // Prepare registration data with check-in time
      final registrationData = {
        'visitorName': _nameController.text,
        'email': _emailController.text,
        'hostName': _useManualHost ? _hostController.text : _selectedHostId,
        'purpose': _purposeController.text,
        'departmentId': _selectedDepartmentId,
        'departmentName': _selectedDepartmentName ?? deptData['name'],
        'campusLocationId': deptData['campusLocationId'] ?? '',
        'visitorLatitude': visitorLat,
        'visitorLongitude': visitorLng,
        'departmentLatitude': deptLat,
        'departmentLongitude': deptLng,
        'distance': distance,
        'registrationDate': Timestamp.fromDate(_registrationDate!),
        'checkInTime': Timestamp.fromDate(_registrationDate!),
        'checkOutTime': null,
        'status': 'active',
      };

      // Save registration
      final docRef = await _firestore
          .collection('visitor_registrations')
          .add(registrationData);
      print('Registration saved successfully with ID: ${docRef.id}');

      if (!mounted) return;

      // Navigate to CampasMapView after check-in
      print(
        'Navigating to CampasMapView with coordinates: visitor=($visitorLat, $visitorLng), target=($deptLat, $deptLng), distance=$distance',
      );
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => CampusMapView(
                targetLatitude: double.parse(deptLat.toString()),
                targetLongitude: double.parse(deptLng.toString()),
                visitorLatitude: visitorLat,
                visitorLongitude: visitorLng,
                // distance: distance,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      String errorMsg;
      if (e.toString().contains('permission')) {
        errorMsg = 'Location permission issue. Please enable in settings.';
      } else if (e.toString().contains('coordinates')) {
        errorMsg = 'Invalid location data. Please try again.';
      } else if (e.toString().contains('Department not found')) {
        errorMsg = 'Selected department not found.';
      } else {
        errorMsg = 'Failed to submit: ${e.toString()}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
      print('Registration error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Registration'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            print('Back button pressed, navigating to HomePage');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(visitorName: ''),
              ),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Registration Date
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registration Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Registration Date: ${_dateFormat.format(_registrationDate!)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Visitor Information
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    hintText: 'Fetched from user profile (edit if needed)',
                  ),
                  validator:
                      (value) => value!.isEmpty ? 'Name is required' : null,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                    hintText: 'Fetched from user profile (edit if needed)',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value!.isEmpty) return 'Email is required';
                    if (!EmailValidator.validate(value))
                      return 'Enter a valid email';
                    return null;
                  },
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),

                // Department Selection
                StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('departments')
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final departments = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedDepartmentId,
                      items:
                          departments.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(data['name'] ?? 'Unknown'),
                            );
                          }).toList(),
                      onChanged:
                          widget.scannedDepartment == null
                              ? (value) {
                                setState(() {
                                  _selectedDepartmentId = value;
                                  _selectedDepartmentName = departments
                                      .firstWhere((doc) => doc.id == value)
                                      .get('name');
                                  _selectedHostId = null;
                                  _useManualHost = false;
                                  _hostController.clear();
                                });
                              }
                              : null,
                      validator:
                          (value) =>
                              value == null ? 'Department is required' : null,
                      disabledHint:
                          widget.scannedDepartment != null
                              ? Text(widget.scannedDepartment!['name'])
                              : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Host Selection
                Row(
                  children: [
                    const Text('Enter host manually:'),
                    Switch(
                      value: _useManualHost,
                      onChanged:
                          _selectedDepartmentId == null
                              ? null
                              : (value) {
                                setState(() {
                                  _useManualHost = value;
                                  _selectedHostId = null;
                                  _hostController.clear();
                                });
                              },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_useManualHost)
                  TextFormField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host Name (Manual Entry)',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator:
                        (value) =>
                            value!.isEmpty ? 'Host name is required' : null,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  )
                else
                  StreamBuilder<QuerySnapshot>(
                    key: ValueKey(_selectedDepartmentId),
                    stream:
                        _selectedDepartmentId != null
                            ? FirebaseFirestore.instance
                                .collection('hosts')
                                .where(
                                  'departmentId',
                                  isEqualTo: _selectedDepartmentId,
                                )
                                .snapshots()
                            : const Stream.empty(),
                    builder: (context, snapshot) {
                      if (_selectedDepartmentId == null) {
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          items: [],
                          onChanged: null,
                          hint: const Text('Select a department first'),
                          validator: (value) => 'Host is required',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final hosts = snapshot.data!.docs;
                      if (hosts.isEmpty) {
                        return Column(
                          children: [
                            TextFormField(
                              controller: _hostController,
                              decoration: const InputDecoration(
                                labelText: 'Host Name (Manual Entry)',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              validator:
                                  (value) =>
                                      value!.isEmpty
                                          ? 'Host name is required'
                                          : null,
                              onChanged: (value) {
                                setState(() {
                                  _useManualHost = true;
                                });
                              },
                              onFieldSubmitted:
                                  (_) => FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No hosts available. Please enter manually or toggle manual entry.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      }
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Host',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedHostId,
                        items:
                            hosts.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(data['name'] ?? 'Unknown'),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedHostId = value;
                            _useManualHost = false;
                          });
                        },
                        validator:
                            (value) =>
                                value == null && !_useManualHost
                                    ? 'Host is required'
                                    : null,
                        hint: const Text('Select a host'),
                      );
                    },
                  ),
                const SizedBox(height: 16),

                // Purpose of Visit
                TextFormField(
                  controller: _purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Purpose of Visit',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator:
                      (value) => value!.isEmpty ? 'Purpose is required' : null,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: 24),

                // Submit Button
                Center(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child:
                        _isSubmitting
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Register Visit',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

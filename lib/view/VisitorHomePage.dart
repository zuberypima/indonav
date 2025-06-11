import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class VisitorHomePage extends StatefulWidget {
  const VisitorHomePage({super.key});

  @override
  _VisitorHomePageState createState() => _VisitorHomePageState();
}

class _VisitorHomePageState extends State<VisitorHomePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();
  final _hostController = TextEditingController();
  String _purpose = 'Meeting';
  String _department = 'Administration';
  String _statusMessage = '';
  String? _timeIn;
  String? _timeOut;
  String? _visitorDocId; // Store Firestore document ID for checkout

  @override
  void initState() {
    super.initState();
    // Ensure Firebase is initialized (called in main.dart, but safe to check here)
    Firebase.initializeApp();
  }

  Future<void> _registerVisitor() async {
    if (_formKey.currentState!.validate()) {
      final visitorData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'idCard': _idCardController.text,
        'host': _hostController.text,
        'purpose': _purpose,
        'department': _department,
        'checkInTime': DateTime.now().toIso8601String(),
        'checkOutTime': null,
      };

      try {
        // Save to Firestore
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('visitors')
            .add(visitorData);

        setState(() {
          _visitorDocId = docRef.id; // Store document ID for checkout
          _timeIn = DateTime.now().toString().substring(0, 19);
          _statusMessage =
              'Visitor ${_nameController.text} registered. Host ${_hostController.text} notified.';
        });

        debugPrint('Visitor Data: $visitorData');
        debugPrint(
          'Access granted for: ${_nameController.text} to meet ${_hostController.text} in $_department',
        );
      } catch (e) {
        setState(() {
          _statusMessage = 'Error registering visitor: $e';
        });
        debugPrint('Error saving to Firestore: $e');
      }
    }
  }

  Future<void> _checkOutVisitor() async {
    if (_visitorDocId == null) {
      setState(() {
        _statusMessage = 'Error: No visitor registered to check out.';
      });
      return;
    }

    try {
      // Update Firestore document with checkout time
      await FirebaseFirestore.instance
          .collection('visitors')
          .doc(_visitorDocId)
          .update({'checkOutTime': DateTime.now().toIso8601String()});

      setState(() {
        _timeOut = DateTime.now().toString().substring(0, 19);
        _statusMessage =
            'Visitor ${_nameController.text} checked out at $_timeOut.';
      });

      debugPrint('Visitor ${_nameController.text} checked out at $_timeOut');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking out visitor: $e';
      });
      debugPrint('Error updating Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Management'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Welcome to the Visitor Management App',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Visitor Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator:
                    (value) => value!.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your email';
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your phone number';
                  if (!RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(value)) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idCardController,
                decoration: const InputDecoration(
                  labelText: 'ID Card Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator:
                    (value) =>
                        value!.isEmpty
                            ? 'Please enter your ID card number'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator:
                    (value) => value!.isEmpty ? 'Please enter host name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _purpose,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Visit',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
                items:
                    ['Meeting', 'Interview', 'Delivery', 'Other']
                        .map(
                          (purpose) => DropdownMenuItem(
                            value: purpose,
                            child: Text(purpose),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _purpose = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _department,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                items:
                    [
                          'Administration',
                          'Computer',
                          'Mechanical',
                          'Civil',
                          'Electrical',
                          'Business',
                          'Hostels',
                        ]
                        .map(
                          (dept) =>
                              DropdownMenuItem(value: dept, child: Text(dept)),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _department = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _timeIn == null ? _registerVisitor : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Register Visitor'),
              ),
              const SizedBox(height: 16),
              if (_timeIn != null)
                ElevatedButton(
                  onPressed: _checkOutVisitor,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Check Out'),
                ),
              const SizedBox(height: 20),
              if (_timeIn != null)
                Text(
                  'Time In: $_timeIn',
                  style: const TextStyle(fontSize: 16, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              if (_timeOut != null)
                Text(
                  'Time Out: $_timeOut',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 16, color: Colors.green),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idCardController.dispose();
    _hostController.dispose();
    super.dispose();
  }
}

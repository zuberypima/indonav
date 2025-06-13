import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:indonav/view/CampasMapView.dart';
import 'package:indonav/view/QRScannerPage.dart';

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
  String? _selectedHostId;
  bool _isSubmitting = false;
  bool _useManualHost = false;

  @override
  void initState() {
    super.initState();
    _nameController.clear();
    _emailController.clear();
    _purposeController.clear();
    _hostController.clear();
    if (widget.scannedDepartment != null) {
      _selectedDepartmentId = widget.scannedDepartment!['departmentId'];
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

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Save registration
      await FirebaseFirestore.instance.collection('visitor_registrations').add({
        'visitorName': _nameController.text,
        'email': _emailController.text,
        'hostName': _useManualHost ? _hostController.text : _selectedHostId,
        'purpose': _purposeController.text,
        'departmentId': _selectedDepartmentId,
        'campusLocationId': widget.scannedDepartment?['campusLocationId'] ?? '',
        'checkInTime': Timestamp.now(),
        'checkOutTime': null,
      });

      // Fetch coordinates
      double? latitude, longitude;
      if (widget.scannedDepartment != null &&
          widget.scannedDepartment!.containsKey('latitude') &&
          widget.scannedDepartment!.containsKey('longitude')) {
        latitude = double.tryParse(
          widget.scannedDepartment!['latitude'].toString(),
        );
        longitude = double.tryParse(
          widget.scannedDepartment!['longitude'].toString(),
        );
      } else {
        final deptDoc =
            await FirebaseFirestore.instance
                .collection('departments')
                .doc(_selectedDepartmentId)
                .get();
        if (deptDoc.exists) {
          final data = deptDoc.data()!;
          latitude = double.tryParse(data['latitude']?.toString() ?? '');
          longitude = double.tryParse(data['longitude']?.toString() ?? '');
        }
      }

      // Fallback coordinates
      latitude ??= 33.416138;
      longitude ??= -8.941800;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to CampasMapView
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => CampasMapView(
                targetLatitude: latitude!,
                targetLongitude: longitude!,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      });
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
            // Navigate back to QRScannerPage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const QRScannerPage()),
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
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator:
                      (value) => value!.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value!.isEmpty) return 'Email is required';
                    if (!EmailValidator.validate(value))
                      return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                        decoration: InputDecoration(
                          labelText: 'Host',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: [],
                        onChanged: null,
                        hint: Text('Select a department first'),
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
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No hosts available for this department. Please enter manually.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
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
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 24),
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
                              'Submit',
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

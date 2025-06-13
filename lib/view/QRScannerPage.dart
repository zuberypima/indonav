import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:indonav/view/VisitorRegistrationPage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  String statusMessage = 'Scan a department QR code';
  bool isProcessing = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    _resetState();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        statusMessage = 'Scan a department QR code';
        isProcessing = false;
      });
    }
  }

  void _onDetect(BarcodeCapture barcodeCapture) async {
    if (isProcessing || barcodeCapture.barcodes.isEmpty || !mounted) return;
    final String? code = barcodeCapture.barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      isProcessing = true;
      statusMessage = 'Processing QR code...';
    });

    try {
      // Parse QR code JSON
      final qrData = jsonDecode(code);
      if (qrData is! Map<String, dynamic> ||
          !qrData.containsKey('departmentId') ||
          !qrData.containsKey('name') ||
          !qrData.containsKey('campusLocationId')) {
        throw const FormatException('Invalid QR code format');
      }

      // Validate optional coordinates
      if (qrData.containsKey('latitude')) {
        qrData['latitude'] =
            double.tryParse(qrData['latitude'].toString())?.toString();
      }
      if (qrData.containsKey('longitude')) {
        qrData['longitude'] =
            double.tryParse(qrData['longitude'].toString())?.toString();
      }

      // Navigate to VisitorRegistrationPage
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => VisitorRegistrationPage(scannedDepartment: qrData),
        ),
      );

      // Reset state after navigation
      _resetState();
    } catch (e) {
      if (mounted) {
        setState(() {
          statusMessage = 'Error: Invalid QR code (${e.toString()})';
          isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Confirm exit if no previous route
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
          title: const Text('QR Code Scanner'),
          centerTitle: true,
          backgroundColor: Colors.deepOrange,
        ),
        body: Column(
          children: [
            Expanded(
              flex: 4,
              child: MobileScanner(
                onDetect: _onDetect,
                controller: _scannerController!,
                // overlay: Container(
                //   decoration: BoxDecoration(
                //     border: Border.all(color: Colors.deepOrange, width: 4),
                //     borderRadius: BorderRadius.circular(10),
                //   ),
                // ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      statusMessage,
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            statusMessage.contains('Error')
                                ? Colors.red
                                : Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

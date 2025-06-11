import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  String scanResult = '';
  String statusMessage = '';
  bool isProcessing = false;

  void _onDetect(BarcodeCapture barcodeCapture) async {
    if (isProcessing || barcodeCapture.barcodes.isEmpty) return;
    final String? code = barcodeCapture.barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      isProcessing = true;
      scanResult = code;
      statusMessage = 'Processing...';
    });

    // Assume scanResult is the Firestore document ID
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('visitors')
              .doc(scanResult)
              .get();

      if (doc.exists) {
        await FirebaseFirestore.instance
            .collection('visitors')
            .doc(scanResult)
            .update({'checkOutTime': DateTime.now().toIso8601String()});

        setState(() {
          statusMessage =
              'Visitor checked out at ${DateTime.now().toString().substring(0, 19)}';
        });
      } else {
        setState(() {
          statusMessage = 'Invalid QR code: Visitor not found';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.normal,
                facing: CameraFacing.back,
              ),
              // overlay: Container(
              //   decoration: BoxDecoration(
              //     border: Border.all(color: Colors.deepOrange, width: 10),
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
                    'Scanned Result: $scanResult',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
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
    );
  }
}

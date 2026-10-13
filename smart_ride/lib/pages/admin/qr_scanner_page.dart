import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// ---------------- qr scanner (admin) ----------------
// scans the user's qr and checks them into their seat
class QRScannerPage extends StatefulWidget {
  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool _processing = false;
  bool _scanComplete = false;
  String _statusMessage = "Point camera at the user's QR code";
  Color _statusColor = Colors.white;
  final MobileScannerController _controller = MobileScannerController();

  Future<void> _handleQRCode(String rawValue) async {
    // ignore scans while busy or already done
    if (_processing || _scanComplete) return;
    setState(() => _processing = true);

    // qr format: utp-smartride|username|busName|seatNumber
    final parts = rawValue.split('|');
    if (parts.length != 4 || parts[0] != 'utp-smartride') {
      setState(() {
        _statusMessage = "❌ Invalid QR code";
        _statusColor = Colors.red;
        _processing = false;
      });
      return;
    }

    final username = parts[1];
    final busName = parts[2];
    final seatNumber = parts[3];

    try {
      final db = FirebaseFirestore.instance;

      // make sure the user exists and is a disabled user
      final userDoc = await db.collection('users').doc(username).get();
      if (!userDoc.exists || userDoc.data()?['isDisabled'] != true) {
        setState(() {
          _statusMessage = "❌ User not authorised for seat booking";
          _statusColor = Colors.red;
          _processing = false;
        });
        return;
      }

      // check the seat isn't taken already
      final seatDoc = await db
          .collection('buses')
          .doc(busName)
          .collection('seats')
          .doc(seatNumber)
          .get();

      if (seatDoc.exists && seatDoc.data()?['status'] == 'taken') {
        setState(() {
          _statusMessage = "⚠️ Seat already booked";
          _statusColor = Colors.orange;
          _processing = false;
        });
        return;
      }

      // mark seat as taken + checked in
      await db
          .collection('buses')
          .doc(busName)
          .collection('seats')
          .doc(seatNumber)
          .set({
        'status': 'taken',
        'checkedIn': true,
        'bookedBy': username,
        'checkedInAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _scanComplete = true;
        _statusMessage =
            "✅ Check-in successful!\n$username → $busName $seatNumber";
        _statusColor = Colors.green;
        _processing = false;
      });

      _controller.stop();
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error: $e";
        _statusColor = Colors.red;
        _processing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan QR Check-In"),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        actions: [
          // lets admin scan the next person
          if (_scanComplete)
            TextButton(
              onPressed: () {
                setState(() {
                  _scanComplete = false;
                  _statusMessage = "Point camera at the user's QR code";
                  _statusColor = Colors.white;
                });
                _controller.start();
              },
              child: Text("Scan Again",
                  style: TextStyle(color: Colors.white)),
            )
        ],
      ),
      body: Column(
        children: [
          // camera view
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _handleQRCode(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          // status area under the camera
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: Colors.grey[900],
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_processing)
                    CircularProgressIndicator(color: Colors.white)
                  else
                    Icon(
                      _scanComplete
                          ? Icons.check_circle
                          : Icons.qr_code_scanner,
                      color: _statusColor,
                      size: 36,
                    ),
                  SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
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

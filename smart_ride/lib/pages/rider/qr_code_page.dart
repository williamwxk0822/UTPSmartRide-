import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'live_tracking_page.dart';

// ---------------- qr code page ----------------
// user shows this to the staff, flips to "confirmed" once scanned
class QRCodePage extends StatelessWidget {
  final String busName;
  final String seatNumber;
  final String username;

  const QRCodePage(
      {required this.busName,
      required this.seatNumber,
      required this.username});

  // same format the scanner expects
  String get _qrData =>
      'utp-smartride|$username|$busName|$seatNumber';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your QR Check-In Code"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      // watch the seat doc to see when staff checks us in
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('buses')
            .doc(busName)
            .collection('seats')
            .doc(seatNumber)
            .snapshots(),
        builder: (context, snapshot) {
          final isCheckedIn = snapshot.hasData &&
              snapshot.data!.exists &&
              snapshot.data!['checkedIn'] == true &&
              snapshot.data!['status'] == 'taken';

          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // already checked in
                  if (isCheckedIn) ...[
                    Icon(Icons.check_circle,
                        color: Colors.green, size: 80),
                    SizedBox(height: 16),
                    Text("Check-In Confirmed!",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                    SizedBox(height: 8),
                    Text("$busName  •  $seatNumber",
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[600])),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveTrackingPage(
                              busName: busName,
                              seatNumber: seatNumber,
                              isDisabled: true,
                              username: username),
                        ),
                      ),
                      child: Text("View Live Tracking"),
                    ),
                  // not checked in yet, show the qr
                  ] else ...[
                    Text("Show this to the bus staff",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("$busName  •  $seatNumber",
                        style: TextStyle(color: Colors.grey[600])),
                    SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.purple.withOpacity(0.25),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.purple.withOpacity(0.18),
                              blurRadius: 30,
                              offset: Offset(0, 10))
                        ],
                      ),
                      child: QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 230,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text("Waiting for staff to scan...",
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Back to map"),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

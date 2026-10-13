import 'package:flutter/material.dart';
import '../../theme/app_ui.dart';
import 'live_tracking_page.dart';

// ---------------- seatbelt confirmation page ----------------
class SeatbeltConfirmationPage extends StatefulWidget {
  final String busName;
  final String seatNumber;
  final String username;
  final String? pickup;
  final String? destination;

  const SeatbeltConfirmationPage({
    required this.busName,
    required this.seatNumber,
    required this.username,
    this.pickup,
    this.destination,
  });

  @override
  State<SeatbeltConfirmationPage> createState() =>
      _SeatbeltConfirmationPageState();
}

class _SeatbeltConfirmationPageState extends State<SeatbeltConfirmationPage> {
  bool _seatbeltFastened = false;

  // can only continue if the checkbox is ticked
  void _confirmSeatbelt() {
    if (!_seatbeltFastened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please confirm your seatbelt is fastened")),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingPage(
          busName: widget.busName,
          seatNumber: widget.seatNumber,
          isDisabled: true,
          username: widget.username,
          pickup: widget.pickup,
          destination: widget.destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Safety Check"),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: AppUI.tintGradient(Colors.amber[600]!),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.amber.withOpacity(0.4),
                        blurRadius: 26,
                        offset: Offset(0, 10)),
                  ],
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 70,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 32),
              Text(
                "Safety First!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[900],
                ),
              ),
              SizedBox(height: 16),
              Text(
                "${widget.busName}  •  ${widget.seatNumber}",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 32),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.amber[700],
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Before proceeding, please ensure your seatbelt is fastened.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.amber[900],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Checkbox(
                    value: _seatbeltFastened,
                    onChanged: (val) {
                      setState(() => _seatbeltFastened = val ?? false);
                    },
                    activeColor: Colors.amber,
                    side: BorderSide(color: Colors.amber, width: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "I confirm my seatbelt is fastened",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _confirmSeatbelt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  minimumSize: Size(double.infinity, 56),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: Text(
                  "Continue to Live Tracking",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

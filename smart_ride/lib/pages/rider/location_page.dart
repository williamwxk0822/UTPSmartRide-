import 'package:flutter/material.dart';
import '../../theme/app_ui.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/gradient_header.dart';
import '../../services/location_service.dart';
import '../auth/login_page.dart';
import '../auth/disability_verification_page.dart';
import 'bus_selection_page.dart';

// ---------------- location page (user home) ----------------
// pick pickup + destination. disabled users must be approved first
class LocationPage extends StatefulWidget {
  final String nickname;
  final String username;
  final bool isDisabled;
  final String verificationStatus;

  const LocationPage({
    required this.nickname,
    required this.username,
    required this.isDisabled,
    required this.verificationStatus,
  });

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  String? selectedPickup;
  String? selectedDestination;

  void proceed() {
    if (selectedPickup == null || selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Please select both pickup and destination")));
      return;
    }
    if (selectedPickup == selectedDestination) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Pickup and destination cannot be the same")));
      return;
    }

    // block disabled users that aren't approved yet
    if (widget.isDisabled && widget.verificationStatus != 'approved') {
      if (widget.verificationStatus == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Your disability card is still being verified. Please wait."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else if (widget.verificationStatus == 'declined') {
        // declined -> snackbar with a resubmit button
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Your verification was declined."),
            action: SnackBarAction(
              label: "Resubmit",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DisabilityVerificationPage(
                      username: widget.username,
                    ),
                  ),
                );
              },
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusSelectionPage(
          pickup: selectedPickup!,
          destination: selectedDestination!,
          isDisabled: widget.isDisabled,
          username: widget.username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hello, ${widget.nickname}"),
        automaticallyImplyLeading: false,
        actions: [
          if (widget.isDisabled)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(Icons.accessible,
                    color: Colors.white, size: 16),
                label: Text("♿",
                    style:
                        TextStyle(color: Colors.white, fontSize: 16)),
                backgroundColor: Colors.purple,
              ),
            ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => LoginPage())),
          )
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: LocationService.stream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final locations = snapshot.data!;
          // clear selection if admin removed that location
          if (selectedPickup != null &&
              !locations.contains(selectedPickup)) selectedPickup = null;
          if (selectedDestination != null &&
              !locations.contains(selectedDestination))
            selectedDestination = null;

          return Padding(
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GradientHeader(
                    title: "Plan your ride",
                    subtitle: "Where are we heading today?",
                    icon: Icons.route_rounded,
                  ),
                  SizedBox(height: 20),
                  // verification banner (pending / declined / approved)
                  if (widget.isDisabled) ...[
                    if (widget.verificationStatus == 'pending')
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(14),
                        decoration: AppUI.banner(Colors.orange),
                        child: Row(children: [
                          IconBadge(
                              icon: Icons.hourglass_top_rounded,
                              color: Colors.orange,
                              size: 38),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  "Your disability card is being verified. You'll have full access once approved.",
                                  style: TextStyle(
                                      color: Colors.orange[900],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      )
                    else if (widget.verificationStatus == 'declined')
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(14),
                        decoration: AppUI.banner(Colors.red),
                        child: Row(children: [
                          IconBadge(
                              icon: Icons.error_outline_rounded,
                              color: Colors.red,
                              size: 38),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  "Your verification was declined. Please resubmit.",
                                  style: TextStyle(
                                      color: Colors.red[900],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      )
                    else
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(14),
                        decoration: AppUI.banner(Colors.purple),
                        child: Row(children: [
                          IconBadge(
                              icon: Icons.verified_rounded,
                              color: Colors.purple,
                              size: 38),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  "Your disability verification is approved. You have seat booking access.",
                                  style: TextStyle(
                                      color: Colors.purple[900],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      ),
                  ],
                  // pickup + destination card
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: AppUI.card(radius: 24),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                              labelText: "Pickup Location",
                              prefixIcon: Icon(Icons.trip_origin_rounded,
                                  color: Colors.green, size: 20)),
                          value: selectedPickup,
                          items: locations
                              .map((loc) => DropdownMenuItem(
                                  value: loc, child: Text(loc)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => selectedPickup = val),
                        ),
                        // little line between the two dropdowns
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const SizedBox(width: 26),
                              Container(
                                width: 2,
                                height: 18,
                                color: const Color(0xFFD5DBE8),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                              labelText: "Destination",
                              prefixIcon: Icon(Icons.location_on_rounded,
                                  color: Colors.red, size: 20)),
                          value: selectedDestination,
                          items: locations
                              .map((loc) => DropdownMenuItem(
                                  value: loc, child: Text(loc)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => selectedDestination = val),
                        ),
                        SizedBox(height: 22),
                        ElevatedButton.icon(
                            onPressed: proceed,
                            icon: Icon(Icons.directions_bus_rounded),
                            label: Text("View Buses")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

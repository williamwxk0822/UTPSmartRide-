import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_ui.dart';
import '../../widgets/icon_badge.dart';
import 'seat_selection_page.dart';
import 'live_tracking_page.dart';

// ---------------- bus selection page ----------------
// disabled users -> pick a seat, normal users -> straight to tracking
class BusSelectionPage extends StatelessWidget {
  final String pickup;
  final String destination;
  final bool isDisabled;
  final String username;

  const BusSelectionPage(
      {required this.pickup,
      required this.destination,
      required this.isDisabled,
      required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select a Bus")),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // shows pickup -> destination
            Container(
              width: double.infinity,
              padding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: AppUI.card(radius: 18),
              child: Row(
                children: [
                  Icon(Icons.trip_origin_rounded,
                      color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                      child: Text(pickup,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppUI.ink))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: AppUI.inkSoft),
                  ),
                  Icon(Icons.location_on_rounded,
                      color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                      child: Text(destination,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppUI.ink))),
                ],
              ),
            ),
            SizedBox(height: 16),
            // bus list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('buses')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return Center(child: CircularProgressIndicator());
                  final buses = snapshot.data?.docs ?? [];
                  if (buses.isEmpty)
                    return Center(child: Text("No buses available."));
                  return ListView.builder(
                    itemCount: buses.length,
                    itemBuilder: (context, index) {
                      final doc = buses[index];
                      final busName = doc.id;
                      final data = doc.data() as Map<String, dynamic>;
                      final route =
                          List<String>.from(data['route'] ?? []);
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: IconBadge(
                              icon: Icons.directions_bus_rounded,
                              color: AppUI.primary),
                          title: Text(busName,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800)),
                          subtitle: route.isEmpty
                              ? Text("No route assigned",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppUI.inkSoft))
                              : Text(route.join("  →  "),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppUI.inkSoft),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: AppUI.primary),
                          onTap: () {
                            if (isDisabled) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SeatSelectionPage(
                                      busName: busName,
                                      username: username,
                                      pickup: pickup,
                                      destination: destination),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LiveTrackingPage(
                                    busName: busName,
                                    seatNumber: "—",
                                    isDisabled: false,
                                    pickup: pickup,
                                    destination: destination,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

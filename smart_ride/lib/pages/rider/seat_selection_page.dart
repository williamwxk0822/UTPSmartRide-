import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_ui.dart';
import 'seatbelt_confirmation_page.dart';

// ---------------- seat selection page ----------------
// only for disabled users
class SeatSelectionPage extends StatefulWidget {
  final String busName;
  final String username;
  final String? pickup;
  final String? destination;
  const SeatSelectionPage(
      {required this.busName,
      required this.username,
      this.pickup,
      this.destination});

  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage> {
  late final CollectionReference seatsRef;

  @override
  void initState() {
    super.initState();
    seatsRef = FirebaseFirestore.instance
        .collection('buses')
        .doc(widget.busName)
        .collection('seats');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.busName} - Select a Seat")),
      // first stream: bus doc (for seat count)
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('buses')
            .doc(widget.busName)
            .snapshots(),
        builder: (context, busSnap) {
          if (!busSnap.hasData)
            return Center(child: CircularProgressIndicator());
          final busData =
              busSnap.data!.data() as Map<String, dynamic>? ?? {};
          final seatCount = (busData['seatCount'] ?? 20) as int;
          final seats =
              List.generate(seatCount, (i) => "Seat ${i + 1}");

          // second stream: which seats are taken
          return StreamBuilder<QuerySnapshot>(
            stream: seatsRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(
                    child: Text("Error: ${snapshot.error}",
                        style: TextStyle(color: Colors.red)));

              final seatDocs = snapshot.data?.docs ?? [];
              final Map<String, String> seatStatus = {
                for (var doc in seatDocs)
                  doc.id: doc['status'] as String
              };

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: AppUI.banner(Colors.purple),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.purple, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                "Select a seat to view the live map. Tap 'Show QR' there when staff arrives.",
                                style: TextStyle(
                                    color: Colors.purple[900],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600))),
                      ]),
                    ),
                    SizedBox(height: 12),
                    // legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegendDot(
                            color: Color(0xFF1B7F3B), label: 'Available'),
                        SizedBox(width: 24),
                        _LegendDot(color: Color(0xFFC62828), label: 'Taken'),
                      ],
                    ),
                    SizedBox(height: 12),
                    // seat grid
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: seats.length,
                        itemBuilder: (context, index) {
                          final seatNumber = seats[index];
                          final isTaken =
                              seatStatus[seatNumber] == 'taken';

                          return ElevatedButton(
                            onPressed: isTaken
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SeatbeltConfirmationPage(
                                          busName: widget.busName,
                                          seatNumber: seatNumber,
                                          username: widget.username,
                                          pickup: widget.pickup,
                                          destination: widget.destination,
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 0),
                              elevation: 0,
                              backgroundColor: isTaken
                                  ? Color(0xFFFFE3E3)
                                  : Color(0xFFE3F6E8),
                              disabledBackgroundColor: Color(0xFFFFE3E3),
                              foregroundColor: isTaken
                                  ? Color(0xFFC62828)
                                  : Color(0xFF1B7F3B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                                side: BorderSide(
                                    color: isTaken
                                        ? Color(0xFFC62828)
                                        : Color(0xFF1B7F3B),
                                    width: 1.2),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    isTaken
                                        ? Icons.event_busy_rounded
                                        : Icons.event_seat_rounded,
                                    size: 14,
                                    color: isTaken
                                        ? Color(0xFFC62828)
                                        : Color(0xFF1B7F3B)),
                                SizedBox(height: 2),
                                Text(seatNumber,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isTaken
                                            ? Color(0xFFC62828)
                                            : Color(0xFF1B7F3B))),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// small colored dot + label for the seat legend
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 14,
            height: 14,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13)),
      ],
    );
  }
}

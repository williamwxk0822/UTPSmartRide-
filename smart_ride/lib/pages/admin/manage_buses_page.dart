import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------- manage buses (admin) ----------------
class ManageBusesPage extends StatefulWidget {
  @override
  State<ManageBusesPage> createState() => _ManageBusesPageState();
}

class _ManageBusesPageState extends State<ManageBusesPage> {
  final _buses = FirebaseFirestore.instance.collection('buses');
  final _newBusController = TextEditingController();
  final _seatCountController = TextEditingController();

  Future<void> _addBus() async {
    final name = _newBusController.text.trim();
    final seatCount = int.tryParse(_seatCountController.text.trim());
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Enter a bus name")));
      return;
    }
    if (seatCount == null || seatCount < 1 || seatCount > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Enter a valid seat count (1–100)")));
      return;
    }
    final doc = await _buses.doc(name).get();
    if (doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bus '$name' already exists")));
      return;
    }
    await _buses.doc(name).set({
      'seatCount': seatCount,
      'route': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    _newBusController.clear();
    _seatCountController.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Bus '$name' added with $seatCount seats"),
        backgroundColor: Colors.green));
  }

  // set every seat of the bus back to available
  Future<void> _resetSeats(String busName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Reset Seats"),
        content: Text("Mark all seats on $busName as available?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Reset",
                  style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    if (confirm != true) return;
    final seatsSnap =
        await _buses.doc(busName).collection('seats').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in seatsSnap.docs) {
      batch.update(doc.reference,
          {'status': 'available', 'checkedIn': false, 'bookedBy': null});
    }
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("All seats on $busName reset"),
        backgroundColor: Colors.orange));
  }

  // delete the bus and all its seats
  Future<void> _deleteBus(String busName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete Bus"),
        content: Text("Delete $busName? This cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final seatsSnap =
        await _buses.doc(busName).collection('seats').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in seatsSnap.docs) batch.delete(doc.reference);
    batch.delete(_buses.doc(busName));
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$busName deleted"), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Manage Buses"),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white),
      body: Column(
        children: [
          // add bus form
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Add New Bus",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _newBusController,
                        decoration: InputDecoration(
                            labelText: 'Bus Name',
                            prefixIcon: Icon(Icons.directions_bus)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _seatCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: 'Seats',
                            prefixIcon: Icon(Icons.event_seat)),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addBus,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: Size(70, 50)),
                      child: Text("Add"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(),
          // bus list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buses.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(child: Text("Error: ${snapshot.error}"));
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty)
                  return Center(child: Text("No buses found."));
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final busName = doc.id;
                    final data = doc.data() as Map<String, dynamic>;
                    final seatCount = data['seatCount'] ?? 20;
                    final route =
                        List<String>.from(data['route'] ?? []);
                    return Card(
                      margin: EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(Icons.directions_bus,
                            color: Colors.teal),
                        title: Text(busName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "$seatCount seats  •  ${route.isEmpty ? 'No route' : '${route.length} stops'}"),
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              child: Text("Reset Seats"),
                              value: 'reset',
                            ),
                            PopupMenuItem(
                              child: Text("Delete Bus"),
                              value: 'delete',
                            ),
                          ],
                          onSelected: (val) {
                            if (val == 'reset') _resetSeats(busName);
                            if (val == 'delete') _deleteBus(busName);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

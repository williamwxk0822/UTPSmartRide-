import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------- verify disabled users (admin) ----------------
// shows users with pending status, admin can approve or decline
class VerifyDisabledUsersPage extends StatelessWidget {
  final _users = FirebaseFirestore.instance.collection('users');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Verify Disabled Users"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _users
            .where('isDisabled', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text("Error: ${snapshot.error}"));

          // only keep the pending ones
          final docs = snapshot.data?.docs ?? [];
          final pendingDocs = docs
              .where((doc) =>
                  (doc.data() as Map<String, dynamic>)['verificationStatus'] ==
                  'pending')
              .toList();

          if (pendingDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text("No pending verifications",
                      style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: pendingDocs.length,
            itemBuilder: (context, index) {
              final doc = pendingDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple[100],
                    child: Icon(Icons.verified_user, color: Colors.purple),
                  ),
                  title: Text(data['nickname'] ?? doc.id,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("@${doc.id} • Pending verification"),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Card ID: ${data['cardId'] ?? 'N/A'}",
                              style: TextStyle(fontSize: 14)),
                          SizedBox(height: 12),
                          if (data['cardPhotoUrl'] != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Card Photo:",
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: Image.network(
                                    data['cardPhotoUrl'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Center(child: Text("Photo unavailable")),
                                    loadingBuilder:
                                        (_, child, progress) =>
                                            progress != null
                                                ? Center(
                                                    child:
                                                        CircularProgressIndicator())
                                                : child,
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(height: 16),
                          Divider(),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              // decline button
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: Icon(Icons.close, color: Colors.red),
                                  label: Text("Decline",
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () async {
                                    final confirm =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text("Decline Verification"),
                                        content: Text(
                                            "Decline ${data['nickname']}? They will need to resubmit."),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text("Decline",
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _users.doc(doc.id).update({
                                        'verificationStatus': 'declined',
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "Verification declined for ${data['nickname']}"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              // approve button
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.check),
                                  label: Text("Approve"),
                                  onPressed: () async {
                                    final confirm =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text("Approve Verification"),
                                        content: Text(
                                            "Approve ${data['nickname']} for disabled user access?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text("Approve",
                                                style: TextStyle(
                                                    color: Colors.green)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _users.doc(doc.id).update({
                                        'verificationStatus': 'approved',
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "Verification approved for ${data['nickname']}"),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

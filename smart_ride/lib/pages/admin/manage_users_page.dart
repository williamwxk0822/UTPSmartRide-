import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------- manage users (admin) ----------------
class ManageUsersPage extends StatelessWidget {
  final _users = FirebaseFirestore.instance.collection('users');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Manage Users"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: _users.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text("Error: ${snapshot.error}"));
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return Center(child: Text("No users found."));
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isDisabled = data['isDisabled'] == true;

              return Card(
                margin: EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isDisabled ? Colors.purple[100] : Colors.indigo[100],
                    child: Icon(
                      isDisabled
                          ? Icons.accessible
                          : Icons.person,
                      color: isDisabled ? Colors.purple : Colors.indigo,
                    ),
                  ),
                  title: Text(data['nickname'] ?? doc.id),
                  subtitle: Text(
                    "@${doc.id}  •  ${isDisabled ? '♿ Disabled' : 'Standard user'}",
                    style: TextStyle(
                        color: isDisabled ? Colors.purple : Colors.grey[600]),
                  ),
                  // delete user (asks first)
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text("Delete User"),
                          content: Text(
                              "Delete @${doc.id}? This cannot be undone."),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: Text("Cancel")),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: Text("Delete",
                                    style: TextStyle(
                                        color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _users.doc(doc.id).delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("User deleted"),
                                backgroundColor: Colors.red));
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

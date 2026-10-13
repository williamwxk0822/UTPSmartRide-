import 'package:flutter/material.dart';
import '../../services/location_service.dart';

// ---------------- manage locations (admin) ----------------
// add / remove / reorder the pickup + destination list
class ManageLocationsPage extends StatefulWidget {
  @override
  State<ManageLocationsPage> createState() => _ManageLocationsPageState();
}

class _ManageLocationsPageState extends State<ManageLocationsPage> {
  final _newLocationController = TextEditingController();

  Future<void> _addLocation(List<String> current) async {
    final name = _newLocationController.text.trim();
    if (name.isEmpty) return;
    // no duplicates (ignore case)
    if (current.map((e) => e.toLowerCase()).contains(name.toLowerCase())) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("'$name' already exists")));
      return;
    }
    await LocationService.save([...current, name]);
    _newLocationController.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("'$name' added"), backgroundColor: Colors.green));
  }

  Future<void> _removeLocation(List<String> current, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Remove Location"),
        content: Text("Remove '$name'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await LocationService.save(
        current.where((l) => l != name).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Manage Locations"),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white),
      body: StreamBuilder<List<String>>(
        stream: LocationService.stream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final locations = snapshot.data!;
          return Column(
            children: [
              // add new location row
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newLocationController,
                        decoration: InputDecoration(
                            labelText: 'New Location Name',
                            prefixIcon:
                                Icon(Icons.add_location_alt)),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _addLocation(locations),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: Size(80, 50)),
                      child: Text("Add"),
                    ),
                  ],
                ),
              ),
              Divider(),
              // drag to reorder, saves the new order
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: locations.length,
                  onReorder: (oldIndex, newIndex) async {
                    final updated = List<String>.from(locations);
                    if (newIndex > oldIndex) newIndex--;
                    final item = updated.removeAt(oldIndex);
                    updated.insert(newIndex, item);
                    await LocationService.save(updated);
                  },
                  itemBuilder: (context, index) {
                    final loc = locations[index];
                    return ListTile(
                      key: ValueKey(loc),
                      leading:
                          Icon(Icons.location_on, color: Colors.orange),
                      title: Text(loc),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.drag_handle, color: Colors.grey),
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _removeLocation(locations, loc),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

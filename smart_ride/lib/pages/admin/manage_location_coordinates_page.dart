import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_ui.dart';
import '../../services/location_service.dart';

// ---------------- manage location coordinates (admin) ----------------
// pick a stop, then set its lat/lng (type it or long-press the map)
class ManageLocationCoordinatesPage extends StatefulWidget {
  @override
  State<ManageLocationCoordinatesPage> createState() => _ManageLocationCoordinatesPageState();
}

class _ManageLocationCoordinatesPageState extends State<ManageLocationCoordinatesPage> {
  final _db = FirebaseFirestore.instance;
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String? _selectedLocation;
  late GoogleMapController _mapController;
  static const LatLng _defaultCenter = LatLng(4.388306, 100.963250);
  LatLng? _selectedCoordinate;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMarker();
  }

  // redraw the marker for the selected point
  void _updateMarker() {
    if (_selectedCoordinate != null) {
      _markers = {
        Marker(
          markerId: const MarkerId("selected"),
          position: _selectedCoordinate!,
          infoWindow: InfoWindow(
            title: "Selected: ${_selectedCoordinate!.latitude.toStringAsFixed(6)}, ${_selectedCoordinate!.longitude.toStringAsFixed(6)}",
          ),
        ),
      };
    } else {
      _markers = {};
    }
  }

  // long press on map fills in the lat/lng fields
  void _onMapLongPress(LatLng position) {
    setState(() {
      _selectedCoordinate = position;
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
      _updateMarker();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Coordinates selected: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // save to locations/coordinates, merge so other stops stay
  Future<void> _saveCoordinates() async {
    if (_selectedLocation == null || _latController.text.isEmpty || _lngController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all fields")),
      );
      return;
    }

    try {
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);

      await _db.collection('locations').doc('coordinates').set(
        {
          _selectedLocation!: {'lat': lat, 'lng': lng}
        },
        SetOptions(merge: true),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Coordinates saved for $_selectedLocation"),
          backgroundColor: Colors.green,
        ),
      );

      // reset the form
      _latController.clear();
      _lngController.clear();
      setState(() {
        _selectedLocation = null;
        _selectedCoordinate = null;
        _updateMarker();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Location Coordinates"),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: AppUI.banner(Colors.deepOrange),
                child: Row(children: [
                  Icon(Icons.touch_app_rounded,
                      color: Colors.deepOrange, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Long-press on map to select coordinates or enter manually.",
                      style: TextStyle(
                          color: Colors.deepOrange[900],
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
              SizedBox(height: 16),
              // map
              Container(
                height: 300,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.deepOrange.withOpacity(0.5),
                      width: 1.4),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppUI.softShadow,
                ),
                child: GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: _selectedCoordinate ?? _defaultCenter,
                    zoom: 14,
                  ),
                  onLongPress: _onMapLongPress,
                  markers: _markers,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: false,
                ),
              ),
              SizedBox(height: 16),
              // location dropdown
              StreamBuilder<List<String>>(
                stream: LocationService.stream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return Center(child: CircularProgressIndicator());
                  final locations = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Location',
                      prefixIcon: Icon(Icons.location_on, color: Colors.deepOrange),
                    ),
                    value: _selectedLocation,
                    items: locations
                        .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedLocation = val),
                  );
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: _latController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  hintText: '4.388306',
                  prefixIcon: Icon(Icons.map, color: Colors.deepOrange),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _lngController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  hintText: '100.963250',
                  prefixIcon: Icon(Icons.map, color: Colors.deepOrange),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveCoordinates,
                icon: Icon(Icons.save),
                label: Text("Save Coordinates"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 24),
              Text(
                "Saved Coordinates",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              // list of saved coordinates
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('locations')
                    .doc('coordinates')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return Center(child: CircularProgressIndicator());

                  final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

                  if (data.isEmpty)
                    return Center(child: Text("No coordinates saved yet"));

                  return Column(
                    children: data.entries.map((entry) {
                      final locName = entry.key;
                      final coords = entry.value as Map<String, dynamic>;
                      final lat = coords['lat'];
                      final lng = coords['lng'];

                      return Card(
                        margin: EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Icon(Icons.location_on, color: Colors.deepOrange),
                          title: Text(locName, style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            "Lat: $lat, Lng: $lng",
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('locations')
                                  .doc('coordinates')
                                  .update({locName: FieldValue.delete()});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Coordinates deleted")),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }
}

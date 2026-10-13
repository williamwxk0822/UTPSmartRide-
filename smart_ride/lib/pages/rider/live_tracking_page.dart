import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/app_config.dart';
import '../../theme/app_ui.dart';
import 'qr_code_page.dart';

// ---------------- live tracking page ----------------
// map with bus position, route to pickup, eta + distance
class LiveTrackingPage extends StatefulWidget {
  final String busName;
  final String seatNumber;
  final bool isDisabled;
  final String? username;
  final String? pickup;
  final String? destination;

  const LiveTrackingPage(
      {required this.busName,
      required this.seatNumber,
      required this.isDisabled,
      this.username,
      this.pickup,
      this.destination});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  GoogleMapController? _mapController;
  LatLng _busLocation = const LatLng(4.388306, 100.963250);
  LatLng? _pickupLocation;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  String _eta = "Loading...";
  String _distance = "";

  // google maps key, used for directions / distance matrix
  static const String _googleMapsApiKey = AppConfig.googleMapsApiKey;

  // don't call the api on every gps update, wait a few secs between calls
  DateTime _lastEtaFetch = DateTime.now().subtract(const Duration(seconds: 10));
  static const Duration _etaThrottle = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    debugPrint('🚌 LiveTrackingPage initialized for bus: ${widget.busName}');
    _initializeLocations();

    // small delay so firebase is ready before we listen
    Future.delayed(Duration(milliseconds: 500), () {
      _listenToBusLocation();
    });

    _updateMarkers();
  }

  // get the pickup coordinates from firestore
  Future<void> _initializeLocations() async {
    try {
      if (widget.pickup != null) {
        debugPrint('🔍 Looking for pickup location: ${widget.pickup}');

        final locDoc = await FirebaseFirestore.instance
            .collection('locations')
            .doc('coordinates')
            .get();

        if (locDoc.exists) {
          final data = locDoc.data() as Map<String, dynamic>;
          debugPrint('📍 Available coordinates: ${data.keys.toList()}');

          if (data.containsKey(widget.pickup)) {
            final coords = data[widget.pickup];
            setState(() {
              _pickupLocation = LatLng(coords['lat'] as double, coords['lng'] as double);
              _updateMarkers();
            });
            debugPrint('✓ Pickup location found: $_pickupLocation');

            // got the pickup, get eta right away
            _updateETAandDistance();
          } else {
            debugPrint('⚠️ Pickup location "${widget.pickup}" not found in coordinates');
          }
        } else {
          debugPrint('⚠️ No coordinates saved yet in Firebase');
        }
      }
    } catch (e) {
      debugPrint("❌ Error initializing locations: $e");
    }
  }

  // listen to the bus gps in realtime database
  void _listenToBusLocation() {
    String path = 'buses/${widget.busName}/location/current';
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🚌 Setting up bus location listener for: $path');

    final ref = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://utpsmartride-db-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref(path);

    // read once first, just to check the connection works
    ref.get().then((snapshot) {
      debugPrint('✓ Initial data fetch successful');
      debugPrint('Data exists: ${snapshot.exists}');
      if (snapshot.exists) {
        debugPrint('Data: ${snapshot.value}');
      }
    }).catchError((e) {
      debugPrint('❌ Initial fetch error: $e');
    });

    // then keep listening for updates
    ref.onValue.listen(
      (DatabaseEvent event) {
        debugPrint('📡 New data received');

        if (event.snapshot.exists) {
          try {
            final snapshot = event.snapshot;
            final latValue = snapshot.child('latitude').value;
            final lngValue = snapshot.child('longitude').value;

            if (latValue != null && lngValue != null) {
              final lat = (latValue as num).toDouble();
              final lng = (lngValue as num).toDouble();

              debugPrint('✅ Bus Location: Lat=$lat, Lng=$lng');

              setState(() {
                _busLocation = LatLng(lat, lng);
                _updateMarkers();
              });

              // move camera to follow the bus
              if (_mapController != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(_busLocation),
                );
              }

              // new bus position -> refresh eta / route
              _updateETAandDistance();
            } else {
              debugPrint('⚠️ latitude=$latValue, longitude=$lngValue');
            }
          } catch (e) {
            debugPrint('❌ Parse error: $e');
          }
        } else {
          debugPrint('⚠️ No snapshot data');
        }
      },
      onError: (error) {
        debugPrint('❌ onValue error: $error');
      },
    );

    debugPrint('═══════════════════════════════════════════════════════');
  }

  // eta + distance + route line, all from one Directions API call.
  // it starts from the bus's current position each time, so the line
  // re-routes by itself if the bus takes a different road.
  // if Directions isn't enabled on the key we fall back to Distance Matrix
  // (eta + distance only, no line)
  Future<void> _updateETAandDistance() async {
    if (_pickupLocation == null) {
      setState(() {
        _distance = "—";
        _eta = "—";
        _polylines = {};
      });
      return;
    }

    // throttle, skip if we called too recently
    final now = DateTime.now();
    if (now.difference(_lastEtaFetch) < _etaThrottle) {
      return;
    }
    _lastEtaFetch = now;

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${_busLocation.latitude},${_busLocation.longitude}'
          '&destination=${_pickupLocation!.latitude},${_pickupLocation!.longitude}'
          '&mode=driving'
          '&units=metric'
          '&key=$_googleMapsApiKey';

      debugPrint('🔗 Fetching route + ETA from Google Directions...');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('{"status":"TIMEOUT"}', 408),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        debugPrint('❌ Directions HTTP error: ${response.statusCode}');
        return;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['status'] != 'OK') {
        debugPrint('⚠️ Directions status: ${data['status']}');
        // REQUEST_DENIED = Directions API not enabled, use the old call
        if (data['status'] == 'REQUEST_DENIED') {
          await _fallbackDistanceMatrix();
        }
        return;
      }

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return;
      final route = routes[0];
      final legs = route['legs'] as List?;
      if (legs == null || legs.isEmpty) return;
      final leg = legs[0];

      final int distanceMeters = leg['distance']['value'] as int;
      final int durationSeconds = leg['duration']['value'] as int;

      // decode the polyline into map points
      final String encoded =
          route['overview_polyline']['points'] as String;
      final List<PointLatLng> decoded =
          PolylinePoints().decodePolyline(encoded);
      final List<LatLng> routePoints = decoded
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      final double distanceKm = distanceMeters / 1000.0;
      final double durationMinutes = durationSeconds / 60.0;

      setState(() {
        // route line from bus to pickup
        _polylines = {
          Polyline(
            polylineId: const PolylineId("bus_route"),
            points: routePoints,
            color: AppUI.primary,
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
            geodesic: true,
          ),
        };

        // format distance (m if under 1 km)
        _distance = distanceKm < 1.0
            ? "$distanceMeters m"
            : "${distanceKm.toStringAsFixed(2)} km";

        // format eta
        if (durationMinutes < 1) {
          _eta = "Arriving now";
        } else if (durationMinutes < 60) {
          _eta = "${durationMinutes.toStringAsFixed(0)} min";
        } else {
          final int hours = (durationMinutes / 60).toInt();
          final int minutes = (durationMinutes % 60).toInt();
          _eta = "$hours h $minutes min";
        }
      });

      debugPrint(
          '✅ Route drawn (${routePoints.length} pts) | $distanceKm km | ETA: $_eta');
    } catch (e) {
      debugPrint('❌ Directions error: $e');
    }
  }

  // old distance matrix version, only used if Directions API isn't enabled
  Future<void> _fallbackDistanceMatrix() async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=${_busLocation.latitude},${_busLocation.longitude}'
          '&destinations=${_pickupLocation!.latitude},${_pickupLocation!.longitude}'
          '&mode=driving'
          '&units=metric'
          '&key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('{"status":"TIMEOUT"}', 408),
      );

      if (!mounted) return;
      if (response.statusCode != 200) return;

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['status'] != 'OK') return;

      final rows = data['rows'] as List?;
      if (rows == null || rows.isEmpty) return;
      final elements = rows[0]['elements'] as List?;
      if (elements == null || elements.isEmpty) return;

      final element = elements[0];
      if (element['status'] != 'OK') return;

      final int distanceMeters = element['distance']['value'] as int;
      final int durationSeconds = element['duration']['value'] as int;

      final double distanceKm = distanceMeters / 1000.0;
      final double durationMinutes = durationSeconds / 60.0;

      setState(() {
        _distance = distanceKm < 1.0
            ? "$distanceMeters m"
            : "${distanceKm.toStringAsFixed(2)} km";

        if (durationMinutes < 1) {
          _eta = "Arriving now";
        } else if (durationMinutes < 60) {
          _eta = "${durationMinutes.toStringAsFixed(0)} min";
        } else {
          final int hours = (durationMinutes / 60).toInt();
          final int minutes = (durationMinutes % 60).toInt();
          _eta = "$hours h $minutes min";
        }
      });

      debugPrint('✅ (Fallback) Road distance: $distanceKm km | ETA: $_eta');
    } catch (e) {
      debugPrint('❌ Distance Matrix fallback error: $e');
    }
  }

  // rebuild the bus + pickup markers
  void _updateMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId("bus"),
        position: _busLocation,
        infoWindow: InfoWindow(
          title: widget.busName,
          snippet: "Bus Location",
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),

      if (_pickupLocation != null)
        Marker(
          markerId: const MarkerId("pickup"),
          position: _pickupLocation!,
          infoWindow: InfoWindow(
            title: widget.pickup,
            snippet: "Pickup Location",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
    };
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.busName} - Live Tracking")),
      body: Stack(
        children: [
          // map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _busLocation,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
          ),

          // debug box, shows the bus coordinates
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.72),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle),
                      ),
                      SizedBox(width: 6),
                      Text(
                        widget.busName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Lat: ${_busLocation.latitude.toStringAsFixed(6)}",
                    style: TextStyle(
                        color: Colors.white70, fontSize: 10.5),
                  ),
                  Text(
                    "Lng: ${_busLocation.longitude.toStringAsFixed(6)}",
                    style: TextStyle(
                        color: Colors.white70, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ),

          // bottom panel (eta, distance, pickup, seat, qr button)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text("ETA",
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: AppUI.inkSoft)),
                              const SizedBox(height: 4),
                              Text(_eta,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppUI.primary)),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: const Color(0xFFE9EDF5),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text("DISTANCE",
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: AppUI.inkSoft)),
                              const SizedBox(height: 4),
                              Text(_distance.isEmpty ? "—" : _distance,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppUI.ink)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.pickup != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 15, color: Colors.red),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Pickup: ${widget.pickup}",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppUI.inkSoft,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // seat chip + qr button, disabled users only
                    if (widget.isDisabled && widget.seatNumber != "—") ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_seat_rounded,
                                size: 15, color: Colors.purple),
                            const SizedBox(width: 5),
                            Text(widget.seatNumber,
                                style: const TextStyle(
                                    color: Colors.purple,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QRCodePage(
                                busName: widget.busName,
                                seatNumber: widget.seatNumber,
                                username: widget.username ?? "Unknown",
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.qr_code_rounded),
                        label: Text("Show QR for Check-In"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

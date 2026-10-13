import 'package:flutter/material.dart';
import '../../theme/app_ui.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/gradient_header.dart';
import '../auth/login_page.dart';
import 'verify_disabled_users_page.dart';
import 'manage_users_page.dart';
import 'manage_buses_page.dart';
import 'manage_locations_page.dart';
import 'manage_location_coordinates_page.dart';
import 'qr_scanner_page.dart';

// ---------------- admin dashboard ----------------
// list of admin tools (verify users, buses, locations, qr scan...)
class AdminDashboardPage extends StatelessWidget {
  final String nickname;
  final String username;
  const AdminDashboardPage(
      {required this.nickname, required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin: $nickname"),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => LoginPage())),
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientHeader(
                title: "Admin Panel",
                subtitle: "Manage users, buses and locations",
                icon: Icons.admin_panel_settings_rounded,
                gradient: AppUI.tintGradient(Colors.red[700]!),
              ),
              SizedBox(height: 24),
              _AdminCard(
                icon: Icons.verified_user,
                title: "Verify Disabled Users",
                subtitle: "Review and approve disability card submissions",
                color: Colors.purple,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => VerifyDisabledUsersPage())),
              ),
              SizedBox(height: 16),
              _AdminCard(
                icon: Icons.people,
                title: "Manage Users",
                subtitle: "View, delete, toggle disabled status",
                color: Colors.indigo,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ManageUsersPage())),
              ),
              SizedBox(height: 16),
              _AdminCard(
                icon: Icons.directions_bus,
                title: "Manage Buses",
                subtitle: "Seats, routes and bus settings",
                color: Colors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ManageBusesPage())),
              ),
              SizedBox(height: 16),
              _AdminCard(
                icon: Icons.location_on,
                title: "Manage Locations",
                subtitle: "Add or remove pickup/destination stops",
                color: Colors.orange,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ManageLocationsPage())),
              ),
              SizedBox(height: 16),
              _AdminCard(
                icon: Icons.location_on_outlined,
                title: "Manage Location Coordinates",
                subtitle: "Set GPS coordinates (lat/lng) for each stop",
                color: Colors.deepOrange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageLocationCoordinatesPage(),
                  ),
                ),
              ),
              SizedBox(height: 16),
              _AdminCard(
                icon: Icons.qr_code_scanner,
                title: "Scan QR Check-In",
                subtitle: "Scan a disabled user's QR code to check them in",
                color: Colors.cyan,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => QRScannerPage())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// one tappable row on the admin dashboard
class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: AppUI.card(),
          child: Row(
            children: [
              IconBadge(icon: icon, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppUI.ink)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppUI.inkSoft)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.chevron_right_rounded,
                    color: color, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

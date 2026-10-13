import 'package:flutter/material.dart';
import '../../theme/app_ui.dart';
import '../../services/auth_service.dart';
import '../admin/admin_dashboard_page.dart';
import '../rider/location_page.dart';
import 'signup_page.dart';
import 'admin_signup_page.dart';

// ---------------- login page ----------------
class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscureText = true;
  bool _isLoading = false;
  int _iconTapCount = 0; // counts taps on the bus icon (hidden admin signup)

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userData = await AuthService.login(
          usernameController.text.trim(), passwordController.text);
      if (userData != null) {
        final nickname = userData['nickname'] ?? usernameController.text;
        final role = userData['role'];
        final username = usernameController.text.trim();
        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardPage(
                  nickname: nickname, username: username),
            ),
          );
        } else {
          final isDisabled = userData['isDisabled'] == true;
          final verificationStatus = userData['verificationStatus'] ?? 'approved';

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LocationPage(
                  nickname: nickname,
                  username: username,
                  isDisabled: isDisabled,
                  verificationStatus: verificationStatus),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Invalid username or password")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Login failed: $e"),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // tap the icon 5 times to open admin signup
  void _onIconTap() {
    _iconTapCount++;
    if (_iconTapCount >= 5) {
      _iconTapCount = 0;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => AdminSignUpPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppUI.primaryGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _onIconTap,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.directions_bus_filled_rounded,
                          size: 54, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("UTP Smart Ride",
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text("Campus rides, tracked live",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Welcome back",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppUI.ink)),
                          const SizedBox(height: 4),
                          const Text("Sign in to continue",
                              style: TextStyle(
                                  color: AppUI.inkSoft, fontSize: 13)),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: usernameController,
                            decoration: InputDecoration(
                                labelText: 'Username',
                                prefixIcon:
                                    Icon(Icons.person_outline_rounded)),
                            validator: (v) => v == null || v.isEmpty
                                ? "Enter a username"
                                : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscureText,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(obscureText
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded),
                                onPressed: () => setState(
                                    () => obscureText = !obscureText),
                              ),
                            ),
                            validator: (v) => v == null || v.length < 6
                                ? "Password too short"
                                : null,
                          ),
                          SizedBox(height: 24),
                          _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: login,
                                  child: const Text("Login")),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => SignUpPage())),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.white),
                    child: const Text("Don't have an account? Sign up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

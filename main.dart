// ================================================================
// FIXED VERSION - All issues resolved:
// 1. Replaced pushReplacementNamed with MaterialPageRoute
// 2. Added resubmit button for declined verification
// 3. All imports verified
// ================================================================

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

// ================================================================
// UI DESIGN KIT — colors, gradients, shadows & reusable widgets.
// Pure presentation. No logic lives here.
// ================================================================
class AppUI {
  // Brand palette
  static const Color primary = Color(0xFF3D5AFE);
  static const Color primaryDark = Color(0xFF1A237E);
  static const Color bg = Color(0xFFF4F6FB);
  static const Color ink = Color(0xFF1B1F2E);
  static const Color inkSoft = Color(0xFF6B7280);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF283593), Color(0xFF3D5AFE), Color(0xFF00B0FF)],
  );

  static LinearGradient tintGradient(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c, Color.lerp(c, Colors.black, 0.25)!],
      );

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF1A237E).withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static BoxDecoration card({double radius = 20}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: softShadow,
      );

  static BoxDecoration banner(Color c) => BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.35)),
      );
}

/// Small rounded icon badge used across cards and banners.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge(
      {required this.icon, required this.color, this.size = 44, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppUI.tintGradient(color),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

/// Gradient page header with title + subtitle, used on dashboards.
class GradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  const GradientHeader(
      {required this.title,
      required this.subtitle,
      required this.icon,
      this.gradient = AppUI.primaryGradient,
      super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppUI.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with comprehensive error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).catchError((error) {
      // Suppress duplicate app errors - Firebase is already running
      if (error.toString().contains('duplicate-app')) {
        debugPrint('✓ Firebase already initialized (duplicate error suppressed)');
        return null;
      }
      throw error;
    });
    debugPrint('✓ Firebase initialized successfully');
  } on FirebaseException catch (e) {
    debugPrint('⚠️ Firebase warning: ${e.code} - ${e.message}');
  } catch (e) {
    debugPrint('⚠️ Firebase catch-all: $e');
  }
  
  runApp(LoginApp());
}

// ================================================================
// AUTH SERVICE
// ================================================================
class AuthService {
  static final _db = FirebaseFirestore.instance;
  static final _users = _db.collection('users');
  static final _admins = _db.collection('admins');

  static Future<Map<String, dynamic>?> login(
      String username, String password) async {
    try {
      final adminDoc = await _admins.doc(username).get();
      if (adminDoc.exists) {
        final data = adminDoc.data()!;
        if (data['password'] == password) return {...data, 'role': 'admin'};
        return null;
      }
      final userDoc = await _users.doc(username).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (data['password'] == password) return {...data, 'role': 'user'};
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  static Future<String?> signUpUser(String username, String password,
      String nickname, bool isDisabled) async {
    try {
      final userDoc = await _users.doc(username).get();
      final adminDoc = await _admins.doc(username).get();
      if (userDoc.exists || adminDoc.exists) return 'Username already exists';
      
      await _users.doc(username).set({
        'password': password,
        'nickname': nickname,
        'isDisabled': isDisabled,
        'verificationStatus': isDisabled ? 'pending' : 'approved',
        'cardId': '',
        'cardPhotoUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<String?> signUpAdmin(
      String username, String password, String nickname) async {
    try {
      final userDoc = await _users.doc(username).get();
      final adminDoc = await _admins.doc(username).get();
      if (userDoc.exists || adminDoc.exists) return 'Username already exists';
      await _admins.doc(username).set({
        'password': password,
        'nickname': nickname,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }
}

// ================================================================
// LOCATION SERVICE
// ================================================================
class LocationService {
  static final _doc =
      FirebaseFirestore.instance.collection('settings').doc('locations');

  static const List<String> _defaultLocations = [
    'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7',
    'Sport Complex', 'Chancellor Hall'
  ];

  static Stream<List<String>> stream() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists || snap.data()?['list'] == null)
        return List<String>.from(_defaultLocations);
      return List<String>.from(snap.data()!['list']);
    });
  }

  static Future<List<String>> get() async {
    final snap = await _doc.get();
    if (!snap.exists || snap.data()?['list'] == null)
      return List<String>.from(_defaultLocations);
    return List<String>.from(snap.data()!['list']);
  }

  static Future<void> save(List<String> locations) async {
    await _doc.set({'list': locations});
  }
}

// ================================================================
// APP ROOT
// ================================================================
class LoginApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTP Smart Ride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppUI.primary)
            .copyWith(primary: AppUI.primary, surface: Colors.white),
        scaffoldBackgroundColor: AppUI.bg,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppUI.ink),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppUI.ink),
          bodyMedium: TextStyle(color: AppUI.ink, height: 1.35),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppUI.ink,
          titleTextStyle: TextStyle(
              color: AppUI.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            elevation: 0,
            backgroundColor: AppUI.primary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF4F6FB),
          labelStyle: const TextStyle(color: AppUI.inkSoft),
          prefixIconColor: AppUI.inkSoft,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE3E7F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppUI.primary, width: 1.6)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: const Color(0xFF1A237E).withOpacity(0.06),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE9EDF5))),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE9EDF5)),
      ),
      home: LoginPage(),
    );
  }
}

// ================================================================
// LOGIN PAGE
// ================================================================
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
  int _iconTapCount = 0;

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

// ================================================================
// UPDATED SIGN UP PAGE - with disabled user option
// ================================================================
class SignUpPage extends StatefulWidget {
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final nicknameController = TextEditingController();
  bool obscureText = true;
  bool _isLoading = false;
  bool _isDisabledUser = false;

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final error = await AuthService.signUpUser(
          usernameController.text.trim(),
          passwordController.text,
          nicknameController.text.trim(),
          _isDisabledUser);
      
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red));
      } else {
        final username = usernameController.text.trim();
        
        // If disabled user, navigate to verification page
        if (_isDisabledUser) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Account created! Please verify your disability card."),
              backgroundColor: Colors.green));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DisabilityVerificationPage(username: username),
            ),
          );
        } else {
          // Regular user - return to login
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Account created! Please log in."),
              backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Sign up failed: $e"),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Account")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: usernameController,
                decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person)),
                validator: (v) =>
                    v == null || v.isEmpty ? "Enter a username" : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: nicknameController,
                decoration: InputDecoration(
                    labelText: 'Nickname',
                    prefixIcon: Icon(Icons.badge)),
                validator: (v) =>
                    v == null || v.isEmpty ? "Enter a nickname" : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(obscureText
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => obscureText = !obscureText),
                  ),
                ),
                validator: (v) => v == null || v.length < 6
                    ? "Minimum 6 characters"
                    : null,
              ),
              SizedBox(height: 24),
              Container(
                decoration: AppUI.banner(Colors.purple),
                child: SwitchListTile(
                  value: _isDisabledUser,
                  onChanged: (val) {
                    setState(() => _isDisabledUser = val);
                  },
                  activeColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  secondary: const IconBadge(
                      icon: Icons.accessible_rounded,
                      color: Colors.purple,
                      size: 40),
                  title: Text("I am a disabled user",
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.purple[800])),
                  subtitle: Text("Requires card verification",
                      style: TextStyle(
                          fontSize: 12, color: Colors.purple[700])),
                ),
              ),
              SizedBox(height: 24),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: register,
                      child: Text("Create Account")),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// NEW: DISABILITY VERIFICATION PAGE
// Users upload card ID and card photo for admin verification
// ================================================================
class DisabilityVerificationPage extends StatefulWidget {
  final String username;
  const DisabilityVerificationPage({required this.username});

  @override
  State<DisabilityVerificationPage> createState() =>
      _DisabilityVerificationPageState();
}

class _DisabilityVerificationPageState
    extends State<DisabilityVerificationPage> {
  final _cardIdController = TextEditingController();
  File? _cardPhoto;
  bool _uploading = false;
  final _imagePicker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _cardPhoto = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  Future<void> _submitVerification() async {
    if (_cardIdController.text.isEmpty || _cardPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and upload a photo")),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      // Upload photo to Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('disability_cards')
          .child(widget.username)
          .child('card_photo.jpg');

      await ref.putFile(_cardPhoto!);
      final photoUrl = await ref.getDownloadURL();

      // Save verification data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.username)
          .update({
        'cardId': _cardIdController.text.trim(),
        'cardPhotoUrl': photoUrl,
        'verificationStatus': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Verification submitted! Admin will review your card shortly.",
          ),
          backgroundColor: Colors.green,
        ),
      );

      // FIXED: Use MaterialPageRoute instead of pushReplacementNamed
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Verify Your Disability Card"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(14),
              decoration: AppUI.banner(Colors.purple),
              child: Row(
                children: [
                  IconBadge(
                      icon: Icons.info_outline_rounded,
                      color: Colors.purple,
                      size: 38),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Please provide your disability card ID and a clear photo of your card for verification.",
                      style: TextStyle(
                          color: Colors.purple[900],
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _cardIdController,
              decoration: InputDecoration(
                labelText: 'Disability Card ID',
                hintText: 'e.g., DIS-2024-12345',
                prefixIcon: Icon(Icons.credit_card, color: Colors.purple),
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Card Photo",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            if (_cardPhoto != null)
              Container(
                width: double.infinity,
                height: 250,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.purple, width: 1.5),
                  boxShadow: AppUI.softShadow,
                ),
                child: Image.file(
                  _cardPhoto!,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFFD5DBE8), width: 1.4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_rounded,
                      size: 44,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 10),
                    Text("No photo yet",
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
              ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _pickImage,
              icon: Icon(Icons.camera_alt),
              label: Text(_cardPhoto == null ? "Take Photo" : "Retake Photo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 32),
            _uploading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text(
                      "Submit for Verification",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cardIdController.dispose();
    super.dispose();
  }
}

// ================================================================
// HIDDEN ADMIN SIGN UP
// ================================================================
class AdminSignUpPage extends StatefulWidget {
  @override
  State<AdminSignUpPage> createState() => _AdminSignUpPageState();
}

class _AdminSignUpPageState extends State<AdminSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final nicknameController = TextEditingController();
  final secretController = TextEditingController();
  bool obscureText = true;
  bool _isLoading = false;
  static const _adminSecret = 'utp-admin-2025';

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    if (secretController.text.trim() != _adminSecret) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Incorrect admin secret code"),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final error = await AuthService.signUpAdmin(
          usernameController.text.trim(),
          passwordController.text,
          nicknameController.text.trim());
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Admin account created!"),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Admin Registration"),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: AppUI.banner(Colors.red),
                  child: Row(children: [
                    IconBadge(
                        icon: Icons.admin_panel_settings_rounded,
                        color: Colors.red,
                        size: 38),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text("Admin accounts stored separately.",
                            style: TextStyle(
                                color: Colors.red[900],
                                fontSize: 13,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),
                SizedBox(height: 24),
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person)),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Enter a username" : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: nicknameController,
                  decoration: InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(Icons.badge)),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Enter a name" : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscureText,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscureText
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => obscureText = !obscureText),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6
                      ? "Minimum 6 characters"
                      : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: secretController,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: 'Admin Secret Code',
                      prefixIcon:
                          Icon(Icons.vpn_key, color: Colors.red)),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Enter secret code" : null,
                ),
                SizedBox(height: 24),
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: register,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700]),
                        child: Text("Create Admin Account")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ADMIN DASHBOARD — Updated with Verify Users option
// ================================================================
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

// ================================================================
// NEW: VERIFY DISABLED USERS PAGE — Admin approval interface
// ================================================================
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

// ================================================================
// ADMIN — MANAGE USERS
// ================================================================
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

// ================================================================
// ADMIN — QR SCANNER PAGE
// ================================================================
class QRScannerPage extends StatefulWidget {
  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool _processing = false;
  bool _scanComplete = false;
  String _statusMessage = "Point camera at the user's QR code";
  Color _statusColor = Colors.white;
  final MobileScannerController _controller = MobileScannerController();

  Future<void> _handleQRCode(String rawValue) async {
    if (_processing || _scanComplete) return;
    setState(() => _processing = true);

    final parts = rawValue.split('|');
    if (parts.length != 4 || parts[0] != 'utp-smartride') {
      setState(() {
        _statusMessage = "❌ Invalid QR code";
        _statusColor = Colors.red;
        _processing = false;
      });
      return;
    }

    final username = parts[1];
    final busName = parts[2];
    final seatNumber = parts[3];

    try {
      final db = FirebaseFirestore.instance;

      final userDoc = await db.collection('users').doc(username).get();
      if (!userDoc.exists || userDoc.data()?['isDisabled'] != true) {
        setState(() {
          _statusMessage = "❌ User not authorised for seat booking";
          _statusColor = Colors.red;
          _processing = false;
        });
        return;
      }

      final seatDoc = await db
          .collection('buses')
          .doc(busName)
          .collection('seats')
          .doc(seatNumber)
          .get();

      if (seatDoc.exists && seatDoc.data()?['status'] == 'taken') {
        setState(() {
          _statusMessage = "⚠️ Seat already booked";
          _statusColor = Colors.orange;
          _processing = false;
        });
        return;
      }

      await db
          .collection('buses')
          .doc(busName)
          .collection('seats')
          .doc(seatNumber)
          .set({
        'status': 'taken',
        'checkedIn': true,
        'bookedBy': username,
        'checkedInAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _scanComplete = true;
        _statusMessage =
            "✅ Check-in successful!\n$username → $busName $seatNumber";
        _statusColor = Colors.green;
        _processing = false;
      });

      _controller.stop();
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error: $e";
        _statusColor = Colors.red;
        _processing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan QR Check-In"),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        actions: [
          if (_scanComplete)
            TextButton(
              onPressed: () {
                setState(() {
                  _scanComplete = false;
                  _statusMessage = "Point camera at the user's QR code";
                  _statusColor = Colors.white;
                });
                _controller.start();
              },
              child: Text("Scan Again",
                  style: TextStyle(color: Colors.white)),
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _handleQRCode(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: Colors.grey[900],
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_processing)
                    CircularProgressIndicator(color: Colors.white)
                  else
                    Icon(
                      _scanComplete
                          ? Icons.check_circle
                          : Icons.qr_code_scanner,
                      color: _statusColor,
                      size: 36,
                    ),
                  SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ADMIN — MANAGE LOCATION COORDINATES
// ================================================================
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

// ================================================================
// MANAGE LOCATIONS
// ================================================================
class ManageLocationsPage extends StatefulWidget {
  @override
  State<ManageLocationsPage> createState() => _ManageLocationsPageState();
}

class _ManageLocationsPageState extends State<ManageLocationsPage> {
  final _newLocationController = TextEditingController();

  Future<void> _addLocation(List<String> current) async {
    final name = _newLocationController.text.trim();
    if (name.isEmpty) return;
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

// ================================================================
// MANAGE BUSES
// ================================================================
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

// ================================================================
// LOCATION PAGE — Updated to check verification status
// FIXED: Added resubmit button for declined verification
// ================================================================
class LocationPage extends StatefulWidget {
  final String nickname;
  final String username;
  final bool isDisabled;
  final String verificationStatus;

  const LocationPage({
    required this.nickname,
    required this.username,
    required this.isDisabled,
    required this.verificationStatus,
  });

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  String? selectedPickup;
  String? selectedDestination;

  void proceed() {
    if (selectedPickup == null || selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Please select both pickup and destination")));
      return;
    }
    if (selectedPickup == selectedDestination) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Pickup and destination cannot be the same")));
      return;
    }

    // Check if disabled user is verified
    if (widget.isDisabled && widget.verificationStatus != 'approved') {
      if (widget.verificationStatus == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Your disability card is still being verified. Please wait."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else if (widget.verificationStatus == 'declined') {
        // FIXED: Added SnackBar action to allow resubmission
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Your verification was declined."),
            action: SnackBarAction(
              label: "Resubmit",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DisabilityVerificationPage(
                      username: widget.username,
                    ),
                  ),
                );
              },
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusSelectionPage(
          pickup: selectedPickup!,
          destination: selectedDestination!,
          isDisabled: widget.isDisabled,
          username: widget.username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hello, ${widget.nickname}"),
        automaticallyImplyLeading: false,
        actions: [
          if (widget.isDisabled)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(Icons.accessible,
                    color: Colors.white, size: 16),
                label: Text("♿",
                    style:
                        TextStyle(color: Colors.white, fontSize: 16)),
                backgroundColor: Colors.purple,
              ),
            ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => LoginPage())),
          )
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: LocationService.stream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final locations = snapshot.data!;
          if (selectedPickup != null &&
              !locations.contains(selectedPickup)) selectedPickup = null;
          if (selectedDestination != null &&
              !locations.contains(selectedDestination))
            selectedDestination = null;

          return Padding(
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GradientHeader(
                    title: "Plan your ride",
                    subtitle: "Where are we heading today?",
                    icon: Icons.route_rounded,
                  ),
                  SizedBox(height: 20),
                  if (widget.isDisabled) ...[
                    if (widget.verificationStatus == 'pending')
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(14),
                        decoration: AppUI.banner(Colors.orange),
                        child: Row(children: [
                          IconBadge(
                              icon: Icons.hourglass_top_rounded,
                              color: Colors.orange,
                              size: 38),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  "Your disability card is being verified. You'll have full access once approved.",
                                  style: TextStyle(
                                      color: Colors.orange[900],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      )
                    else if (widget.verificationStatus == 'declined')
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(14),
                        decoration: AppUI.banner(Colors.red),
                        child: Row(children: [
                          IconBadge(
                              icon: Icons.error_outline_rounded,
                              color: Colors.red,
                              size: 38),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  "Your verification was declined. Please resubmit.",
                                  style: TextStyle(
                                      color: Colors.red[900],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      )
                    else
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(14),
                        decoration: AppUI.banner(Colors.purple),
                        child: Row(children: [
                          IconBadge(
                              icon: Icons.verified_rounded,
                              color: Colors.purple,
                              size: 38),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  "Your disability verification is approved. You have seat booking access.",
                                  style: TextStyle(
                                      color: Colors.purple[900],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      ),
                  ],
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: AppUI.card(radius: 24),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                              labelText: "Pickup Location",
                              prefixIcon: Icon(Icons.trip_origin_rounded,
                                  color: Colors.green, size: 20)),
                          value: selectedPickup,
                          items: locations
                              .map((loc) => DropdownMenuItem(
                                  value: loc, child: Text(loc)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => selectedPickup = val),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const SizedBox(width: 26),
                              Container(
                                width: 2,
                                height: 18,
                                color: const Color(0xFFD5DBE8),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                              labelText: "Destination",
                              prefixIcon: Icon(Icons.location_on_rounded,
                                  color: Colors.red, size: 20)),
                          value: selectedDestination,
                          items: locations
                              .map((loc) => DropdownMenuItem(
                                  value: loc, child: Text(loc)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => selectedDestination = val),
                        ),
                        SizedBox(height: 22),
                        ElevatedButton.icon(
                            onPressed: proceed,
                            icon: Icon(Icons.directions_bus_rounded),
                            label: Text("View Buses")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// BUS SELECTION PAGE
// ================================================================
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

// ================================================================
// SEAT SELECTION PAGE — disabled users only
// ================================================================
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

// ================================================================
// SEATBELT CONFIRMATION PAGE
// ================================================================
class SeatbeltConfirmationPage extends StatefulWidget {
  final String busName;
  final String seatNumber;
  final String username;
  final String? pickup;
  final String? destination;

  const SeatbeltConfirmationPage({
    required this.busName,
    required this.seatNumber,
    required this.username,
    this.pickup,
    this.destination,
  });

  @override
  State<SeatbeltConfirmationPage> createState() =>
      _SeatbeltConfirmationPageState();
}

class _SeatbeltConfirmationPageState extends State<SeatbeltConfirmationPage> {
  bool _seatbeltFastened = false;

  void _confirmSeatbelt() {
    if (!_seatbeltFastened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please confirm your seatbelt is fastened")),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingPage(
          busName: widget.busName,
          seatNumber: widget.seatNumber,
          isDisabled: true,
          username: widget.username,
          pickup: widget.pickup,
          destination: widget.destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Safety Check"),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: AppUI.tintGradient(Colors.amber[600]!),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.amber.withOpacity(0.4),
                        blurRadius: 26,
                        offset: Offset(0, 10)),
                  ],
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 70,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 32),
              Text(
                "Safety First!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[900],
                ),
              ),
              SizedBox(height: 16),
              Text(
                "${widget.busName}  •  ${widget.seatNumber}",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 32),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.amber[700],
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Before proceeding, please ensure your seatbelt is fastened.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.amber[900],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Checkbox(
                    value: _seatbeltFastened,
                    onChanged: (val) {
                      setState(() => _seatbeltFastened = val ?? false);
                    },
                    activeColor: Colors.amber,
                    side: BorderSide(color: Colors.amber, width: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "I confirm my seatbelt is fastened",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _confirmSeatbelt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  minimumSize: Size(double.infinity, 56),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: Text(
                  "Continue to Live Tracking",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// QR CODE PAGE
// ================================================================
class QRCodePage extends StatelessWidget {
  final String busName;
  final String seatNumber;
  final String username;

  const QRCodePage(
      {required this.busName,
      required this.seatNumber,
      required this.username});

  String get _qrData =>
      'utp-smartride|$username|$busName|$seatNumber';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your QR Check-In Code"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('buses')
            .doc(busName)
            .collection('seats')
            .doc(seatNumber)
            .snapshots(),
        builder: (context, snapshot) {
          final isCheckedIn = snapshot.hasData &&
              snapshot.data!.exists &&
              snapshot.data!['checkedIn'] == true &&
              snapshot.data!['status'] == 'taken';

          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isCheckedIn) ...[
                    Icon(Icons.check_circle,
                        color: Colors.green, size: 80),
                    SizedBox(height: 16),
                    Text("Check-In Confirmed!",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                    SizedBox(height: 8),
                    Text("$busName  •  $seatNumber",
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[600])),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveTrackingPage(
                              busName: busName,
                              seatNumber: seatNumber,
                              isDisabled: true,
                              username: username),
                        ),
                      ),
                      child: Text("View Live Tracking"),
                    ),
                  ] else ...[
                    Text("Show this to the bus staff",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("$busName  •  $seatNumber",
                        style: TextStyle(color: Colors.grey[600])),
                    SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.purple.withOpacity(0.25),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.purple.withOpacity(0.18),
                              blurRadius: 30,
                              offset: Offset(0, 10))
                        ],
                      ),
                      child: QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 230,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text("Waiting for staff to scan...",
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Back to map"),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

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

// ================================================================
// LIVE TRACKING PAGE
// ================================================================
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

  // 🔑 Google Maps API Key (Distance Matrix API) - used for road-based ETA/distance
  static const String _googleMapsApiKey =
      'AIzaSyAMl_NDTSjZ6pu9MD7LGcrmtm_65R73wqw';

  // Throttle so we don't spam the Distance Matrix API on every GPS tick
  DateTime _lastEtaFetch = DateTime.now().subtract(const Duration(seconds: 10));
  static const Duration _etaThrottle = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    debugPrint('🚌 LiveTrackingPage initialized for bus: ${widget.busName}');
    _initializeLocations();
    
    // Delay listener setup to ensure Firebase is fully ready
    Future.delayed(Duration(milliseconds: 500), () {
      _listenToBusLocation();
    });
    
    _updateMarkers();
  }

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

            // We now know the pickup, so try fetching ETA/distance right away
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

  void _listenToBusLocation() {
    String path = 'buses/${widget.busName}/location/current';
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🚌 Setting up bus location listener for: $path');
    
    final ref = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://utpsmartride-db-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref(path);
    
    // First, try to read data once to verify connection
    ref.get().then((snapshot) {
      debugPrint('✓ Initial data fetch successful');
      debugPrint('Data exists: ${snapshot.exists}');
      if (snapshot.exists) {
        debugPrint('Data: ${snapshot.value}');
      }
    }).catchError((e) {
      debugPrint('❌ Initial fetch error: $e');
    });
    
    // Now set up continuous listener
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
              
              if (_mapController != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(_busLocation),
                );
              }

              // 🆕 Recalculate ETA/distance using Google Maps on every new bus position
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

  // ================================================================
  // 🆕 ETA + DISTANCE + ROUTE — one Google Maps Directions API call
  // returns the road route (polyline), distance and duration.
  // The route is recalculated from the bus's CURRENT position on
  // every refresh, so if the bus drives a different road than the
  // drawn one, the line automatically re-routes on the next update.
  // Falls back to Distance Matrix (ETA/distance only, no route line)
  // if the Directions API is not enabled on the key.
  // ================================================================
  Future<void> _updateETAandDistance() async {
    if (_pickupLocation == null) {
      setState(() {
        _distance = "—";
        _eta = "—";
        _polylines = {};
      });
      return;
    }

    // Throttle: only call the API once every few seconds
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
        // Key probably doesn't have Directions API enabled — keep
        // ETA/distance working through the old Distance Matrix call.
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

      // Decode the encoded overview polyline into map points
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
        // Route line: bus → pickup, redrawn from the live bus position
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

      debugPrint(
          '✅ Route drawn (${routePoints.length} pts) | $distanceKm km | ETA: $_eta');
    } catch (e) {
      debugPrint('❌ Directions error: $e');
    }
  }

  // Old Distance Matrix logic, kept as a fallback so ETA/distance
  // still work even if the Directions API isn't enabled on the key.
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
          // Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _busLocation,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
          ),
          
          // DEBUG: Show bus coordinates on screen
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
          
          // Bottom info panel
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
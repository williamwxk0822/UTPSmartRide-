import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../theme/app_ui.dart';
import '../../widgets/icon_badge.dart';
import '../../services/auth_service.dart';

// ---------------- hidden admin sign up ----------------
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
  static const _adminSecret = AppConfig.adminSecret;

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    // check the secret code before creating anything
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

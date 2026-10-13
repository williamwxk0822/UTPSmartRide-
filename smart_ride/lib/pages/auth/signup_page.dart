import 'package:flutter/material.dart';
import '../../theme/app_ui.dart';
import '../../widgets/icon_badge.dart';
import '../../services/auth_service.dart';
import 'disability_verification_page.dart';

// ---------------- sign up page ----------------
// has the "disabled user" switch
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

        // disabled users go verify their card first
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
          // normal user, back to login
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

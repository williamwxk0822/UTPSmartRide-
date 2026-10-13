import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_ui.dart';
import '../../widgets/icon_badge.dart';
import 'login_page.dart';

// ---------------- disability verification page ----------------
// user enters card id + takes a photo, admin checks it later
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

  // open camera and keep the photo
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
      // upload the photo to storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('disability_cards')
          .child(widget.username)
          .child('card_photo.jpg');

      await ref.putFile(_cardPhoto!);
      final photoUrl = await ref.getDownloadURL();

      // save card id + photo url on the user doc, status back to pending
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

      // done, go back to login
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
            // show the photo if taken, otherwise an empty placeholder
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

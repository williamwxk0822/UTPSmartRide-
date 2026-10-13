import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // start firebase, don't crash if something goes wrong
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).catchError((error) {
      // duplicate-app just means it's already running, ignore it
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

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------- auth service ----------------
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

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TextMessageService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    // Request permission for notifications
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get the token
    String? token = await _messaging.getToken();
    if (token != null) {
      // Save the token to Firestore
      await _saveTokenToFirestore(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    if (_auth.currentUser != null) {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'fcmToken': token,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendTextMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Get the user's FCM token from Firestore
      final userDoc = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      if (userDoc.docs.isEmpty) {
        throw Exception('User not found');
      }

      final fcmToken = userDoc.docs.first.data()['fcmToken'];
      if (fcmToken == null) {
        throw Exception('User has no FCM token');
      }

      // Send the message using Firebase Cloud Functions
      // Note: You'll need to implement the Cloud Function separately
      await _firestore.collection('messages').add({
        'to': fcmToken,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }
} 
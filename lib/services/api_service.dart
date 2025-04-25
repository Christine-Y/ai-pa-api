import 'package:cloud_firestore/cloud_firestore.dart';

class ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sends a message to a specific phone number
  /// Returns the message ID if successful
  Future<String> sendMessage({
    required String destinationID,
    required String text,
  }) async {
    try {
      final docRef = await _firestore.collection('messages').add({
        'text': text,
        'destinationID': destinationID,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Gets all messages for a specific phone number
  Future<List<Map<String, dynamic>>> getMessages(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('messages')
          .where('destinationID', isEqualTo: phoneNumber)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
                'timestamp': doc.data()['timestamp']?.toDate(),
              })
          .toList();
    } catch (e) {
      throw Exception('Failed to get messages: $e');
    }
  }

  /// Deletes a specific message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }
} 
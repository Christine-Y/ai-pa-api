import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call_record.dart';

class CallRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'call_records';

  Future<void> addCallRecord(CallRecord record) async {
    try {
      await _firestore.collection(_collection).doc(record.id).set(record.toMap());
    } catch (e) {
      throw Exception('Failed to add call record: $e');
    }
  }

  Future<void> addCallRecordFromApi(Map<String, dynamic> data) async {
    try {
      final record = CallRecord(
        id: data['id'] as String,
        phoneNumber: data['phoneNumber'] as String,
        timestamp: DateTime.parse(data['timestamp'] as String),
        summary: data['summary'] as String,
        metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      );
      await addCallRecord(record);
    } catch (e) {
      throw Exception('Failed to add call record from API: $e');
    }
  }

  Future<List<CallRecord>> getCallRecordsByPhone(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => CallRecord.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get call records: $e');
    }
  }
} 
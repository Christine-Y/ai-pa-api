class CallRecord {
  final String id;
  final String phoneNumber;
  final DateTime timestamp;
  final String summary;
  final Map<String, dynamic> metadata;

  CallRecord({
    required this.id,
    required this.phoneNumber,
    required this.timestamp,
    required this.summary,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'timestamp': timestamp.toIso8601String(),
      'summary': summary,
      'metadata': metadata,
    };
  }

  factory CallRecord.fromMap(Map<String, dynamic> map) {
    return CallRecord(
      id: map['id'] as String,
      phoneNumber: map['phoneNumber'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      summary: map['summary'] as String,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
} 
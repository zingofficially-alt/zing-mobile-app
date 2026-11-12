import 'package:cloud_firestore/cloud_firestore.dart';

class ZingNotification {
  final String id;
  final String title;
  final String body;
  final String type; // order, promo, system
  final bool isRead;
  final Timestamp createdAt;
  final Map<String, dynamic>? data;

  ZingNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.data,
  });

  factory ZingNotification.fromDocument(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ZingNotification(
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: d['type'] ?? 'system',
      isRead: d['isRead'] ?? false,
      createdAt: d['createdAt'] ?? Timestamp.now(),
      data: d['data'],
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'body': body,
    'type': type,
    'isRead': isRead,
    'createdAt': createdAt,
    'data': data,
  };
}

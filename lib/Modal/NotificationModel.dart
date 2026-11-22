import 'package:zing/Modal/types.dart';

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

  factory ZingNotification.fromRow(Map<String, dynamic> d) {
    return ZingNotification(
      id: d['id'] ?? '',
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: d['type'] ?? 'system',
      isRead: d['is_read'] ?? false,
      createdAt: Timestamp.parse(d['created_at']),
      data: (d['data'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

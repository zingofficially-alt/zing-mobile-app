import 'package:zing/Modal/types.dart';

class Message {
  final String messageId;
  final String senderId;
  final String message;
  final DateTime timestamp;
  final bool isImage;
  final bool isUploading;
  final bool isSending;

  /// Fields for replying/quoting:
  final String? replyToText;
  final String? replyToSenderName;

  Message({
    required this.messageId,
    required this.senderId,
    required this.message,
    required this.timestamp,
    this.isImage = false,
    this.isUploading = false,
    this.isSending = false,
    this.replyToText,
    this.replyToSenderName,
  });

  /// Creates a message from a `chat_messages` row.
  factory Message.fromRow(Map<String, dynamic> r) {
    return Message(
      messageId: r['id'] ?? '',
      senderId: r['sender_id'] ?? '',
      message: r['message'] ?? '',
      timestamp: Timestamp.parse(r['created_at']).toDate(),
      isImage: r['is_image'] ?? false,
      replyToText: r['reply_to_text'] as String?,
      replyToSenderName: r['reply_to_sender_name'] as String?,
    );
  }

  Message copyWith({
    String? messageId,
    String? senderId,
    String? message,
    DateTime? timestamp,
    bool? isImage,
    bool? isUploading,
    bool? isSending,
    String? replyToText,
    String? replyToSenderName,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isImage: isImage ?? this.isImage,
      isUploading: isUploading ?? this.isUploading,
      isSending: isSending ?? this.isSending,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
    );
  }
}

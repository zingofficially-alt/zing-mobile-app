import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/Modal/types.dart';
import 'package:zing/Service/StorageService.dart';
import '../Modal/ChatMessage.dart';

class ChatProvider with ChangeNotifier {
  // Messages of the currently active chat, newest first.
  List<Message> _messages = [];
  List<Message> get messages => _messages;

  // All chats of this store (the store's "inbox").
  List<Map<String, dynamic>> allChats = [];

  SupabaseClient get _db => Supabase.instance.client;
  RealtimeChannel? _channel;

  // --------------------------------------------------------------------------
  // 1) The store's chat list (the "inbox")
  Future<void> fetchAllUserChats(String storeId) async {
    try {
      final rows = await _db
          .from('chats')
          .select()
          .eq('store_id', storeId)
          .order('last_updated', ascending: false);

      allChats = (rows as List)
          .map((r) => {
                'chatId': r['id'],
                'customerId': r['user_id'],
                'lastMessage': r['last_message'] ?? '',
                'lastUpdated': Timestamp.parse(r['last_updated']),
              })
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching all user chats: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 2) Messages of one chat, newest first, then listen for new ones in realtime
  Future<void> fetchMessages(String chatId) async {
    try {
      final rows = await _db
          .from('chat_messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: false);

      _messages = (rows as List).map((r) => Message.fromRow(r)).toList();
      notifyListeners();
      _listen(chatId);
    } catch (e) {
      print('Error fetching messages: $e');
      rethrow;
    }
  }

  void _listen(String chatId) {
    _channel?.unsubscribe();
    _channel = _db
        .channel('chat:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'chat_id', value: chatId),
          callback: (payload) {
            final incoming = Message.fromRow(payload.newRecord);
            if (_messages.any((m) => m.messageId == incoming.messageId)) return;
            _messages.insert(0, incoming);
            notifyListeners();
          },
        )
        .subscribe();
  }

  // --------------------------------------------------------------------------
  // 3) Gets or creates the chat between a user and a store; returns its id.
  Future<String> createChat({
    required String userId,
    required String storeId,
  }) async {
    try {
      final existing = await _db
          .from('chats')
          .select('id')
          .eq('user_id', userId)
          .eq('store_id', storeId)
          .maybeSingle();
      if (existing != null) return existing['id'] as String;

      final created = await _db
          .from('chats')
          .insert({'user_id': userId, 'store_id': storeId})
          .select('id')
          .single();
      return created['id'] as String;
    } catch (e) {
      debugPrint('Error creating chat: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // 4) Send a text message (with optional reply info)
  Future<void> sendMessage(
    String chatId,
    String senderId,
    String messageText, {
    String? replyToText,
    String? replyToSenderName,
  }) async {
    final tempMessage = Message(
      messageId: DateTime.now().toIso8601String(),
      senderId: senderId,
      message: messageText,
      timestamp: DateTime.now(),
      isImage: false,
      isUploading: false,
      replyToText: replyToText,
      replyToSenderName: replyToSenderName,
    );
    _messages.insert(0, tempMessage);
    notifyListeners();

    try {
      // The database trigger updates the chat's lastMessage / lastUpdated.
      final row = await _db
          .from('chat_messages')
          .insert({
            'chat_id': chatId,
            'sender_id': senderId,
            'message': messageText,
            'is_image': false,
            if (replyToText != null) 'reply_to_text': replyToText,
            if (replyToSenderName != null) 'reply_to_sender_name': replyToSenderName,
          })
          .select()
          .single();

      _messages.remove(tempMessage);
      final finalMessage = Message.fromRow(row);
      if (!_messages.any((m) => m.messageId == finalMessage.messageId)) {
        _messages.insert(0, finalMessage);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error sending message: $e');
      _messages.remove(tempMessage);
      notifyListeners();
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // 5) Send an image (with an ephemeral "uploading" state)
  Future<String> sendImage(
    String chatId,
    String senderId,
    File imageFile, {
    String? replyToText,
    String? replyToSenderName,
  }) async {
    final tempMessage = Message(
      messageId: DateTime.now().toIso8601String(),
      senderId: senderId,
      message: imageFile.path, // local file path as placeholder
      timestamp: DateTime.now(),
      isImage: true,
      isUploading: true,
      replyToText: replyToText,
      replyToSenderName: replyToSenderName,
    );
    _messages.insert(0, tempMessage);
    notifyListeners();

    try {
      final imageUrl = await StorageService.uploadFile(
          Buckets.chat, '$chatId/${DateTime.now().millisecondsSinceEpoch}.jpg', imageFile);

      final row = await _db
          .from('chat_messages')
          .insert({
            'chat_id': chatId,
            'sender_id': senderId,
            'message': imageUrl,
            'is_image': true,
            if (replyToText != null) 'reply_to_text': replyToText,
            if (replyToSenderName != null) 'reply_to_sender_name': replyToSenderName,
          })
          .select()
          .single();

      _messages.remove(tempMessage);
      final finalMessage = Message.fromRow(row);
      if (!_messages.any((m) => m.messageId == finalMessage.messageId)) {
        _messages.insert(0, finalMessage);
      }
      notifyListeners();
      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      _messages.remove(tempMessage);
      notifyListeners();
      throw Exception('Failed to upload image');
    }
  }

  // --------------------------------------------------------------------------
  Future<void> deleteMessage(String chatId, Message message) async {
    try {
      await _db.from('chat_messages').delete().eq('id', message.messageId);
      _messages.removeWhere((m) => m.messageId == message.messageId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  void addMessage(String chatId, Message message) {
    _messages.insert(0, message);
    notifyListeners();
  }

  void updateMessage(String chatId, Message updatedMessage) {
    final index = _messages.indexWhere((m) => m.messageId == updatedMessage.messageId);
    if (index != -1) {
      _messages[index] = updatedMessage;
      notifyListeners();
    }
  }

  void removeMessage(String chatId, Message message) {
    _messages.removeWhere((m) => m.messageId == message.messageId);
    notifyListeners();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/Modal/NotificationModel.dart';

class NotificationProvider with ChangeNotifier {
  List<ZingNotification> _notifications = [];
  StreamSubscription? _subscription;
  StreamSubscription<AuthState>? _authSub;
  bool _isLoading = true;

  SupabaseClient get _db => Supabase.instance.client;

  List<ZingNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  List<ZingNotification> get todayNotifications {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _notifications.where((n) => n.createdAt.toDate().isAfter(startOfDay)).toList();
  }

  List<ZingNotification> get yesterdayNotifications {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
    return _notifications.where((n) {
      final date = n.createdAt.toDate();
      return date.isAfter(startOfYesterday) && date.isBefore(startOfToday);
    }).toList();
  }

  List<ZingNotification> get earlierNotifications {
    final now = DateTime.now();
    final startOfYesterday =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    return _notifications.where((n) => n.createdAt.toDate().isBefore(startOfYesterday)).toList();
  }

  /// Streams the signed-in user's notifications in realtime, and restarts the
  /// stream whenever the user signs in or out.
  void startListening() {
    _authSub ??= _db.auth.onAuthStateChange.listen((_) => _subscribe());
    _subscribe();
  }

  void _subscribe() {
    final uid = _db.auth.currentUser?.id;
    _subscription?.cancel();
    _subscription = null;
    if (uid == null) {
      _notifications = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _subscription = _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50)
        .listen((rows) {
      _notifications = rows.map(ZingNotification.fromRow).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Notification listener error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    if (_db.auth.currentUser == null) return;
    await _db.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

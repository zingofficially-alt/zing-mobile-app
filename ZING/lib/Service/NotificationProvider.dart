import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zing/Modal/NotificationModel.dart';

class NotificationProvider with ChangeNotifier {
  List<ZingNotification> _notifications = [];
  StreamSubscription? _subscription;
  bool _isLoading = true;

  List<ZingNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  List<ZingNotification> get todayNotifications {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _notifications.where((n) =>
        n.createdAt.toDate().isAfter(startOfDay)).toList();
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
    final startOfYesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    return _notifications.where((n) =>
        n.createdAt.toDate().isBefore(startOfYesterday)).toList();
  }

  void startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      _notifications = snapshot.docs
          .map((doc) => ZingNotification.fromDocument(doc))
          .toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Notification listener error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final n in _notifications.where((n) => !n.isRead)) {
      batch.update(
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(n.id),
        {'isRead': true},
      );
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

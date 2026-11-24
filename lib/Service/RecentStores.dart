import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the stores this device opened most recently, newest first.
/// Kept on the device only; nothing is sent to the server.
class RecentStores {
  RecentStores._();

  static const _key = 'recent_store_ids';
  static const _max = 8;

  /// Store ids, newest first. Listen to rebuild when it changes.
  static final ValueNotifier<List<String>> ids = ValueNotifier<List<String>>(const []);
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      ids.value = prefs.getStringList(_key) ?? const [];
    } catch (_) {}
  }

  static Future<void> add(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return;
    await load();
    final next = [storeId, ...ids.value.where((id) => id != storeId)].take(_max).toList();
    ids.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next);
    } catch (_) {}
  }

  static Future<void> clear() async {
    ids.value = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

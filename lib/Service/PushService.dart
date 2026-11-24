import 'package:shared_preferences/shared_preferences.dart';

/// The customer's "notifications" preference on this device.
///
/// Order and chat updates arrive in the app through Supabase Realtime
/// (NotificationProvider). Delivering them as phone push notifications while
/// the app is closed needs an FCM/APNs sender (for example a Supabase Edge
/// Function that reads a device-token table), which is not built yet. Until
/// then this only stores the switch from Settings so that sender can honour it.
class PushService {
  PushService._();

  static const _key = 'push_enabled';

  static Future<bool> isEnabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, value);
    } catch (_) {
      // Preference is a convenience; ignore storage failures.
    }
  }
}

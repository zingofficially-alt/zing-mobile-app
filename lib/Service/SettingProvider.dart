import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsProvider with ChangeNotifier {
  double? registrationAmount;
  String? currency;

  SupabaseClient get _db => Supabase.instance.client;

  Future<Map<String, dynamic>?> _load() =>
      _db.from('app_settings').select().eq('id', 'default').maybeSingle();

  Future<void> fetchGlobalRegistrationAmount() async {
    try {
      final row = await _load();
      if (row != null) {
        registrationAmount = (row['registration_amount'] as num?)?.toDouble() ?? 0.0;
        currency = row['currency'] ?? 'USD';
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching global registration amount: $e');
    }
  }

  /// Admin only (enforced by Row Level Security).
  Future<void> updateRegistrationAmount(double newAmount, String newCurrency) async {
    try {
      await _db.from('app_settings').upsert({
        'id': 'default',
        'registration_amount': newAmount,
        'currency': newCurrency,
      });
      registrationAmount = newAmount;
      currency = newCurrency;
      notifyListeners();
    } catch (e) {
      print('Error updating registration amount: $e');
    }
  }

  Future<double> getRegistrationAmount() async {
    final row = await _load();
    if (row == null) throw Exception('Registration settings not found.');
    return (row['registration_amount'] as num?)?.toDouble() ?? 0.0;
  }

  Future<String> getCurrency() async {
    final row = await _load();
    if (row == null) throw Exception('Currency settings not found.');
    return row['currency'] ?? 'USD';
  }
}

import 'package:zing/Service/ApiClient.dart';

/// Talks to the Node API (`/events`, `/recommendations`), which replaced the
/// Firebase Cloud Functions that used Google Cloud Retail.
class RecommendationService {
  /// Extracts the product uuid from a catalog id such as `product_<store>_<id>`.
  static String? _productId(String raw) {
    if (!raw.startsWith('product_')) return raw;
    final parts = raw.split('_');
    return parts.isEmpty ? null : parts.last;
  }

  /// Logs a user event. Fire-and-forget: never throws.
  Future<void> logEvent({
    required String eventType,
    String? userId,
    required String visitorId,
    List<String>? productIds,
    String? attributionToken,
    double? purchaseAmount,
    String? transactionId,
  }) async {
    if (userId == null) return; // events are stored per signed-in user
    try {
      final ids = productIds ?? const <String>[];
      await ApiClient.post('/events', {
        'event_type': eventType,
        if (ids.isNotEmpty) 'product_id': _productId(ids.first),
      });
    } catch (_) {
      // Never surface event logging errors to the user.
    }
  }

  /// Fetches recommendations. Returns empty results on any error, which makes
  /// the provider use its local fallback.
  Future<Map<String, dynamic>> getRecommendations({
    required String placement,
    String? userId,
    required String visitorId,
    List<String>? productIds,
    String? filter,
  }) async {
    if (userId == null) return {'results': <String>[], 'attributionToken': ''};
    try {
      final data = await ApiClient.get('/recommendations', query: {'limit': '20'})
          .timeout(const Duration(seconds: 10));
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

      final ids = <String>[];
      final storeIds = <String>{};
      for (final p in items) {
        ids.add('product_${p['store_id']}_${p['id']}');
        storeIds.add('store_${p['store_id']}');
      }
      return {'results': [...storeIds, ...ids], 'attributionToken': ''};
    } catch (_) {
      return {'results': <String>[], 'attributionToken': ''};
    }
  }
}

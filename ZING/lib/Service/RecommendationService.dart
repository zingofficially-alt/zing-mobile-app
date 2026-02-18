import 'package:cloud_functions/cloud_functions.dart';

class RecommendationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Logs a user event to Vertex AI Retail. Fire-and-forget — never throws.
  Future<void> logEvent({
    required String eventType,
    String? userId,
    required String visitorId,
    List<String>? productIds,
    String? attributionToken,
    double? purchaseAmount,
    String? transactionId,
  }) async {
    try {
      await _functions.httpsCallable('logUserEvent').call({
        'eventType': eventType,
        'userId': userId,
        'visitorId': visitorId,
        'productIds': productIds ?? [],
        'attributionToken': attributionToken ?? '',
        if (purchaseAmount != null) 'purchaseAmount': purchaseAmount,
        if (transactionId != null) 'transactionId': transactionId,
      });
    } catch (_) {
      // Fire-and-forget: never surface event logging errors to the user
    }
  }

  /// Fetches recommendations from Vertex AI Retail Predict API.
  /// Returns empty list + empty token on any error (triggers fallback).
  Future<Map<String, dynamic>> getRecommendations({
    required String placement,
    String? userId,
    required String visitorId,
    List<String>? productIds,
    String? filter,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('getRecommendations')
          .call({
            'placement': placement,
            'userId': userId,
            'visitorId': visitorId,
            'productIds': productIds ?? [],
            'filter': filter ?? '',
          })
          .timeout(const Duration(seconds: 10));

      final data = result.data as Map<dynamic, dynamic>;
      return {
        'results': List<String>.from(data['results'] ?? []),
        'attributionToken': data['attributionToken'] ?? '',
      };
    } catch (_) {
      return {'results': <String>[], 'attributionToken': ''};
    }
  }
}

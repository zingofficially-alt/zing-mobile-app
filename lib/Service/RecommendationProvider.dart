import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'RecommendationService.dart';

class RecommendationProvider extends ChangeNotifier {
  // Placement name constants matching Cloud Function serving config IDs
  static const String homeRecommended = 'home_recommended';
  static const String storeAlsoViewed = 'store_also_viewed';
  static const String cartBoughtTogether = 'cart_bought_together';
  static const String postOrderStores = 'post_order_stores';

  final RecommendationService _service = RecommendationService();

  final Map<String, List<String>> _results = {};
  final Map<String, bool> _loading = {};
  final Map<String, String> _attributionTokens = {};

  List<String> getResults(String placement) => _results[placement] ?? [];
  bool isLoading(String placement) => _loading[placement] ?? false;
  String getToken(String placement) => _attributionTokens[placement] ?? '';

  String get _visitorId {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return uid ?? 'anonymous';
  }

  Future<void> fetchRecommendations({
    required String placement,
    List<String>? productIds,
    String? filter,
  }) async {
    _loading[placement] = true;
    notifyListeners();

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final data = await _service.getRecommendations(
        placement: placement,
        userId: uid,
        visitorId: _visitorId,
        productIds: productIds,
        filter: filter,
      );
      _results[placement] = List<String>.from(data['results'] ?? []);
      _attributionTokens[placement] = data['attributionToken'] ?? '';
    } catch (_) {
      _results[placement] = [];
    } finally {
      _loading[placement] = false;
      notifyListeners();
    }
  }

  Future<void> logEvent({
    required String eventType,
    List<String>? productIds,
    String? attributionToken,
    double? purchaseAmount,
    String? transactionId,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    await _service.logEvent(
      eventType: eventType,
      userId: uid,
      visitorId: _visitorId,
      productIds: productIds,
      attributionToken: attributionToken,
      purchaseAmount: purchaseAmount,
      transactionId: transactionId,
    );
  }

  /// Fallback: returns stores sorted by popularity (ratings count, descending).
  List<Store> applyStoreFallback(List<Store> allStores, {int limit = 10}) {
    final sorted = List<Store>.from(allStores)
      ..sort((a, b) => b.ratings.length.compareTo(a.ratings.length));
    return sorted.take(limit).toList();
  }

  /// Fallback: returns context products shuffled.
  List<Product> applyProductFallback(List<Product> contextProducts,
      {int limit = 10}) {
    final shuffled = List<Product>.from(contextProducts)..shuffle(Random());
    return shuffled.take(limit).toList();
  }

  /// Resolves Retail catalog IDs (e.g. "store_abc") to Store objects.
  List<Store> resolveStores(List<String> resultIds, List<Store> allStores) {
    final storeMap = {for (final s in allStores) s.id: s};
    final resolved = <Store>[];
    for (final id in resultIds) {
      if (id.startsWith('store_')) {
        final storeId = id.substring('store_'.length);
        final store = storeMap[storeId];
        if (store != null) resolved.add(store);
      }
    }
    return resolved;
  }

  /// Resolves Retail catalog IDs (e.g. "product_storeId_prodId") to Product objects.
  List<Product> resolveProducts(
      List<String> resultIds, List<Store> allStores) {
    final Map<String, Product> productMap = {};
    for (final store in allStores) {
      for (final product in store.products) {
        final key = 'product_${store.id}_${product.id}';
        productMap[key] = product;
      }
    }
    final resolved = <Product>[];
    for (final id in resultIds) {
      final product = productMap[id];
      if (product != null) resolved.add(product);
    }
    return resolved;
  }
}

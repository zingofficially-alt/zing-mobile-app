import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Modal/CoustomUser.dart';

/// A reason an order could not be placed or changed, worded for the customer.
class OrderException implements Exception {
  final String message;
  const OrderException(this.message);
  @override
  String toString() => message;
}

class OrderProvider with ChangeNotifier {
  List<Orders> _orders = [];
  SupabaseClient get _db => Supabase.instance.client;

  List<Orders> get orders => _orders;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Orders of one store, newest first, with line items and buyer details.
  Future<void> fetchOrdersByStore(BuildContext context, String storeId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final rows = await _db
          .from('orders')
          .select(Orders.select)
          .eq('store_id', storeId)
          .order('placed_at', ascending: false);
      _orders = (rows as List).map((r) => Orders.fromRow(r)).toList();
    } catch (e, stackTrace) {
      print('Error fetching orders: $e\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> placeOrder(
    String userId,
    Store store,
    List<Product> products,
    double totalPrice,
    String deliveryMethod,
    CustomUser userData, {
    double deliveryFee = 0.0,
    String? deliveryAddress,
  }) async {
    // `products` holds one entry per unit. The database prices the items,
    // adds the delivery fee, checks and reserves stock in one transaction
    // (place_order in 0004_order_rules.sql), so [totalPrice] and
    // [deliveryFee] are only what the screen showed.
    final units = <String, int>{};
    for (final p in products) {
      if (p.id.isEmpty) continue;
      units[p.id] = (units[p.id] ?? 0) + 1;
    }
    try {
      await _db.rpc('place_order', params: {
        'p_store_id': store.id,
        'p_items': [
          for (final e in units.entries) {'product_id': e.key, 'quantity': e.value},
        ],
        'p_delivery_method': deliveryMethod,
        'p_delivery_address': deliveryAddress,
      });
    } on PostgrestException catch (e) {
      debugPrint('Error placing order: ${e.message}');
      // The database explains the problem (out of stock, pickup only, ...).
      throw OrderException(e.message);
    }
  }

  /// Moves an order on (store owner). The database allows only the next
  /// step or a cancellation, and records who cancelled.
  Future<void> updateOrderStatus(String storeId, String orderId, String newStatus) async {
    try {
      await _db.from('orders').update({'status': newStatus}).eq('id', orderId);
      for (final o in _orders) {
        if (o.id == orderId) {
          o.status = newStatus;
          if (newStatus == OrderStatus.cancelled) o.cancelledBy = 'store';
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  /// Cancels an order the customer placed. Allowed only while it is still
  /// pending; the database puts the stock back and tells the store.
  Future<void> cancelOrderAsCustomer(Orders order) async {
    if (!order.canCustomerCancel) {
      throw const OrderException('This order can no longer be cancelled.');
    }
    try {
      await _db.from('orders').update({'status': OrderStatus.cancelled}).eq('id', order.id);
    } on PostgrestException catch (e) {
      throw OrderException(e.message);
    }
    order.status = OrderStatus.cancelled;
    order.cancelledBy = 'customer';
    notifyListeners();
  }

  /// A user's orders across all stores, newest first.
  Future<List<Orders>> fetchUserOrdersAcrossStores(String userId) async {
    try {
      final rows = await _db
          .from('orders')
          .select(Orders.select)
          .eq('user_id', userId)
          .order('placed_at', ascending: false);
      return (rows as List).map((r) => Orders.fromRow(r)).toList();
    } catch (e) {
      print('Error fetching user orders: $e');
      return [];
    }
  }
}

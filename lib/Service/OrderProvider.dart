import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Modal/CoustomUser.dart';

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
    try {
      final order = await _db
          .from('orders')
          .insert({
            'user_id': userId,
            'store_id': store.id,
            'delivery_method': deliveryMethod,
            'delivery_fee': deliveryFee,
            if (deliveryAddress != null && deliveryAddress.isNotEmpty)
              'delivery_address': deliveryAddress,
            'status': 'Pending',
            'total_price': totalPrice,
          })
          .select('id')
          .single();

      await _db.from('order_items').insert(products
          .map((p) => {
                'order_id': order['id'],
                'product_id': p.id.isEmpty ? null : p.id,
                'name': p.name,
                'price': p.price,
                'image_url': p.imageUrl,
                'quantity': p.quantity,
              })
          .toList());
    } catch (e) {
      print('Error placing order: $e');
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String storeId, String orderId, String newStatus) async {
    try {
      await _db.from('orders').update({'status': newStatus}).eq('id', orderId);
      notifyListeners();
    } catch (e) {
      print('Error updating order status: $e');
    }
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

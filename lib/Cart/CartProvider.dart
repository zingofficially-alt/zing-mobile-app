import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:zing/Modal/CoustomUser.dart'; // Assuming you have a Product model
import '../Service/CoustomUserProvider.dart';

/// Define CartItem model
class CartItem {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final String? storeId;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.storeId,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'storeId': storeId,
      'quantity': quantity,
    };
  }

  /// Row of the `cart_items` table.
  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'product_id': id,
        'store_id': storeId,
        'name': name,
        'price': price,
        'image_url': imageUrl,
        'quantity': quantity,
      };

  factory CartItem.fromRow(Map<String, dynamic> r) => CartItem(
        id: r['product_id'],
        name: r['name'] ?? '',
        price: (r['price'] as num).toDouble(),
        imageUrl: r['image_url'],
        storeId: r['store_id'],
        quantity: r['quantity'] ?? 1,
      );

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      name: map['name'],
      price: map['price'].toDouble(),
      imageUrl: map['imageUrl'],
      storeId: map['storeId'],
      quantity: map['quantity'] ?? 1,
    );
  }
}

// Define CartProvider
class CartProvider with ChangeNotifier {
  List<CartItem> _items = [];
  bool _isLoading = true;
  String _userId = '';

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;

  double get totalPrice {
    return _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  void setUserId(String userId) {
    _userId = userId;
  }

  Future<void> loadCart(BuildContext context) async {
    if (_userId.isEmpty) return;

    try {
      _isLoading = true;
      notifyListeners();

      final rows = await Supabase.instance.client
          .from('cart_items')
          .select()
          .eq('user_id', _userId);

      _items = (rows as List).map((r) => CartItem.fromRow(r)).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print("Error loading cart: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addItem(CartItem item, BuildContext context) async {
    if (_userId.isEmpty) return;

    try {
      final existingItemIndex = _items.indexWhere((i) => i.id == item.id);

      if (existingItemIndex >= 0) {
        // If item exists, increase quantity
        _items[existingItemIndex].quantity += 1;

        await Supabase.instance.client
            .from('cart_items')
            .update({'quantity': _items[existingItemIndex].quantity})
            .eq('user_id', _userId)
            .eq('product_id', item.id);
      } else {
        // Otherwise add new item
        _items.add(item);

        await Supabase.instance.client
            .from('cart_items')
            .upsert(item.toRow(_userId));
      }

      notifyListeners();
    } catch (e) {
      print("Error adding item to cart: $e");
    }
  }

  Future<void> updateItemQuantity(CartItem item, int quantity, BuildContext context) async {
    if (_userId.isEmpty) return;

    try {
      final existingItemIndex = _items.indexWhere((i) => i.id == item.id);

      if (existingItemIndex >= 0) {
        _items[existingItemIndex].quantity = quantity;

        await Supabase.instance.client
            .from('cart_items')
            .update({'quantity': quantity})
            .eq('user_id', _userId)
            .eq('product_id', item.id);

        notifyListeners();
      }
    } catch (e) {
      print("Error updating cart item quantity: $e");
    }
  }

  Future<void> removeItem(CartItem item, BuildContext context) async {
    if (_userId.isEmpty) return;

    try {
      // Remove from local list
      _items.removeWhere((i) => i.id == item.id);

      await Supabase.instance.client
          .from('cart_items')
          .delete()
          .eq('user_id', _userId)
          .eq('product_id', item.id);

      notifyListeners();
    } catch (e) {
      print("Error removing item from cart: $e");
    }
  }

  Future<void> clearCart(BuildContext context) async {
    if (_userId.isEmpty) return;

    try {
      // Clear local list
      _items.clear();

      await Supabase.instance.client.from('cart_items').delete().eq('user_id', _userId);

      notifyListeners();
    } catch (e) {
      print("Error clearing cart: $e");
    }
  }
}

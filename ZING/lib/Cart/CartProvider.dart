import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> loadCartFromFirestore(BuildContext context) async {
    if (_userId.isEmpty) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Get cart items from Firestore
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .get();

      // Clear current items and add items from Firestore
      _items = [];
      for (var doc in cartSnapshot.docs) {
        _items.add(CartItem.fromMap(doc.data()));
      }

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

        // Update quantity in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('cart')
            .doc(item.id)
            .update({'quantity': _items[existingItemIndex].quantity});
      } else {
        // Otherwise add new item
        _items.add(item);

        // Add to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('cart')
            .doc(item.id)
            .set(item.toMap());
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

        // Update quantity in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('cart')
            .doc(item.id)
            .update({'quantity': quantity});

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

      // Remove from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .doc(item.id)
          .delete();

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

      // Get all cart items
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .get();

      // Delete each item
      for (var doc in cartSnapshot.docs) {
        await doc.reference.delete();
      }

      notifyListeners();
    } catch (e) {
      print("Error clearing cart: $e");
    }
  }
}

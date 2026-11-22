import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/Modal/types.dart';

export 'package:zing/Modal/types.dart';

SupabaseClient get _db => Supabase.instance.client;

/// PostgREST select string that loads a store with everything the UI shows.
const String kStoreSelect =
    '*, products(*), store_videos(*), store_ratings(user_id, rating), '
    'owner:profiles!owner_id(id, name, email, phone_number, profile_image_url)';

// Helper to sanitize image URLs - removes placeholder URLs
String _sanitizeImageUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.contains('via.placeholder.com')) return '';
  return url;
}

double? _num(dynamic v) => v == null ? null : (v as num).toDouble();

class CustomUser {
  String id; // Supabase auth user id (uuid)
  String name;
  String email;
  String phoneNumber;
  String address;
  String profileImageUrl;
  bool storeAccess;
  String role;
  bool? hasPaid;
  Store? store; // Optional Store property for users with the role 'Owner'
  List<String>? favorites;
  List<Payment>? payments;

  CustomUser({
    this.hasPaid,
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.storeAccess = false,
    this.address = '',
    this.profileImageUrl = '',
    this.role = 'User',
    this.store,
    this.favorites = const [],
    this.payments = const [],
  });

  void addFavorite(String storeId) {
    if (!favorites!.contains(storeId)) {
      favorites!.add(storeId);
    }
  }

  void removeFavorite(String storeId) {
    favorites!.remove(storeId);
  }

  Future<List<Payment>> fetchPayments() async {
    try {
      final rows = await _db
          .from('payments')
          .select()
          .eq('user_id', id)
          .order('paid_at', ascending: false);
      payments = (rows as List).map((r) => Payment.fromRow(r)).toList();
      return payments!;
    } catch (e) {
      print('Error fetching payments: $e');
      return [];
    }
  }

  /// Columns of the `profiles` table (role/store_access/has_paid are only
  /// accepted from admins; a database trigger ignores them otherwise).
  Map<String, dynamic> toRow() => {
        'id': id,
        'name': name,
        'email': email,
        'phone_number': phoneNumber,
        'address': address,
        'profile_image_url': profileImageUrl,
        'role': role,
        'store_access': storeAccess,
        'has_paid': hasPaid ?? false,
      };

  /// Kept for code that serialises a user snapshot (e.g. order details).
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'storeAccess': storeAccess,
        'hasPaid': hasPaid ?? false,
        'phoneNumber': phoneNumber,
        'address': address,
        'profileImageUrl': profileImageUrl,
        'role': role,
        'favorites': favorites ?? [],
      };

  /// Builds a user from a `profiles` row. [store] and [favorites] come from
  /// related tables and are optional.
  factory CustomUser.fromRow(
    Map<String, dynamic> r, {
    Store? store,
    List<String>? favorites,
    List<Payment>? payments,
  }) {
    return CustomUser(
      id: r['id'] ?? '',
      name: r['name'] ?? '',
      email: r['email'] ?? '',
      phoneNumber: r['phone_number'] ?? '',
      address: r['address'] ?? '',
      profileImageUrl: r['profile_image_url'] ?? '',
      role: r['role'] ?? 'User',
      storeAccess: r['store_access'] ?? false,
      hasPaid: r['has_paid'] ?? false,
      store: store,
      favorites: favorites ?? [],
      payments: payments ?? [],
    );
  }

  factory CustomUser.fromMap(Map<String, dynamic> data) {
    return CustomUser(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      storeAccess: data['storeAccess'] ?? false,
      phoneNumber: data['phoneNumber'] ?? '',
      address: data['address'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      role: data['role'] ?? 'User',
      hasPaid: data['hasPaid'] ?? false,
      favorites: List<String>.from(data['favorites'] ?? []),
    );
  }
}

class Store {
  String? id; // Store unique ID (uuid)
  double? registrationsAmount;
  final String name;
  final String description;
  List<Rating> ratings;
  final String category;
  final String imageUrl;
  final List<Product> products;
  final List<Order>? orders;
  final Owner owner;
  final GeoPoint location;
  final bool isFavourite;
  final String phoneNumber;
  List<YouTubeVideo>? videos;
  List<String>? deliveryOptions;
  double? deliveryCost;

  Store({
    required this.phoneNumber,
    this.id,
    this.registrationsAmount,
    required this.name,
    required this.description,
    this.ratings = const [],
    required this.category,
    required this.imageUrl,
    required this.products,
    required this.owner,
    required this.location,
    this.isFavourite = false,
    this.orders,
    this.videos = const [],
    this.deliveryOptions = const [],
    this.deliveryCost,
  });

  Future<double> getAverageRating() async {
    if (id == null || id!.isEmpty) return 0.0;
    try {
      final rows =
          await _db.from('store_rating_summary').select('avg_rating').eq('store_id', id!);
      if ((rows as List).isEmpty) return 0.0;
      return _num(rows.first['avg_rating']) ?? 0.0;
    } catch (e) {
      print('Error fetching ratings: $e');
      return 0.0;
    }
  }

  Future<void> submitRating(String userId, double rating) async {
    if (id == null || id!.isEmpty) {
      print('Cannot submit rating: Store ID is null or empty');
      return;
    }
    try {
      await _db.from('store_ratings').upsert({
        'store_id': id,
        'user_id': userId, // each user can rate a store once
        'rating': rating,
      });
    } catch (e) {
      print('Error submitting rating: $e');
    }
  }

  Future<bool> userHasRated(String userId) async {
    if (id == null || id!.isEmpty) return false;
    try {
      final row = await _db
          .from('store_ratings')
          .select('user_id')
          .eq('store_id', id!)
          .eq('user_id', userId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      print('Error checking if user has rated: $e');
      return false;
    }
  }

  /// Columns of the `stores` table. Products, videos and ratings live in
  /// their own tables and are written separately.
  Map<String, dynamic> toRow() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'owner_id': owner.id,
        'name': name,
        'description': description,
        'category': category,
        'image_url': imageUrl,
        'phone_number': phoneNumber,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'registration_amount': registrationsAmount,
        'delivery_options': deliveryOptions ?? [],
        'delivery_cost': deliveryCost,
      };

  /// Builds a store from a row loaded with [kStoreSelect].
  static Store fromRow(Map<String, dynamic> r) {
    final ownerRow = (r['owner'] as Map<String, dynamic>?) ?? const {};
    return Store(
      id: r['id'],
      phoneNumber: r['phone_number'] ?? '',
      name: r['name'] ?? '',
      registrationsAmount: _num(r['registration_amount']),
      description: r['description'] ?? '',
      ratings: ((r['store_ratings'] as List?) ?? [])
          .map((m) => Rating.fromRow(m as Map<String, dynamic>))
          .toList(),
      category: r['category'] ?? '',
      imageUrl: _sanitizeImageUrl(r['image_url']),
      products: ((r['products'] as List?) ?? [])
          .map((m) => Product.fromRow(m as Map<String, dynamic>))
          .toList(),
      owner: Owner.fromRow(ownerRow, fallbackId: r['owner_id'] ?? ''),
      location: GeoPoint(_num(r['latitude']) ?? 0, _num(r['longitude']) ?? 0),
      videos: ((r['store_videos'] as List?) ?? [])
          .map((m) => YouTubeVideo.fromMap(m as Map<String, dynamic>))
          .toList(),
      deliveryOptions:
          ((r['delivery_options'] as List?) ?? []).map((e) => e as String).toList(),
      deliveryCost: _num(r['delivery_cost']),
    );
  }

  /// Snapshot map (used to embed a store in a notification or order view).
  Map<String, dynamic> toMap() => {
        'id': id,
        'registrationAmount': registrationsAmount,
        'phoneNumber': phoneNumber,
        'name': name,
        'description': description,
        'category': category,
        'imageUrl': imageUrl,
        'owner': owner.toMap(),
        'deliveryOptions': deliveryOptions,
        'deliveryCost': deliveryCost,
      };
}

class Payment {
  late final String paymentId;
  final String storeId;
  final double amount;
  final String currency;
  final String items;
  late final String paymentStatus;
  final Timestamp paymentDate;

  Payment({
    required this.storeId,
    required this.paymentId,
    required this.amount,
    required this.currency,
    required this.items,
    required this.paymentStatus,
    required this.paymentDate,
  });

  static Payment fromRow(Map<String, dynamic> r) => Payment(
        paymentId: (r['external_payment_id'] ?? r['id'] ?? '').toString(),
        amount: _num(r['amount']) ?? 0,
        currency: r['currency'] ?? '',
        items: r['items'] ?? '',
        paymentStatus: r['payment_status'] ?? '',
        paymentDate: Timestamp.parse(r['paid_at']),
        storeId: (r['store_id'] ?? '').toString(),
      );

  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'store_id': storeId.isEmpty ? null : storeId,
        'external_payment_id': paymentId.isEmpty ? null : paymentId,
        'amount': amount,
        'currency': currency,
        'items': items,
        'payment_status': paymentStatus,
        'paid_at': paymentDate.toIso(),
      };
}

class Product {
  String id = '';
  final String name;
  final String? description;
  final double price;
  final double? rating;
  final String? imageUrl;
  final bool isAvailable;
  final double? discount;
  final int quantity;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.rating,
    this.imageUrl,
    this.isAvailable = true,
    this.discount,
    this.quantity = 0,
  });

  /// Columns of the `products` table.
  Map<String, dynamic> toRow(String storeId) => {
        if (id.isNotEmpty) 'id': id,
        'store_id': storeId,
        'name': name,
        'description': description,
        'price': price,
        'rating': rating,
        'image_url': imageUrl,
        'is_available': isAvailable,
        'discount': discount,
        'quantity': quantity,
      };

  static Product fromRow(Map<String, dynamic> r) => Product(
        id: r['id'] ?? '',
        name: r['name'] ?? '',
        description: r['description'] ?? '',
        price: _num(r['price']) ?? 0.0,
        rating: _num(r['rating']) ?? 0.0,
        imageUrl: _sanitizeImageUrl(r['image_url']),
        isAvailable: r['is_available'] ?? true,
        discount: _num(r['discount']),
        quantity: r['quantity'] ?? 0,
      );

  /// Snapshot map (order line items).
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'rating': rating,
        'imageUrl': imageUrl,
        'isAvailable': isAvailable,
        'discount': discount,
        'quantity': quantity,
      };

  static Product fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        price: map['price']?.toDouble() ?? 0.0,
        rating: map['rating']?.toDouble() ?? 0.0,
        imageUrl: _sanitizeImageUrl(map['imageUrl']),
        isAvailable: map['isAvailable'] ?? true,
        discount: map['discount']?.toDouble(),
        quantity: map['quantity'] ?? 0,
      );
}

class Owner {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profileImageUrl;

  Owner({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImageUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'profileImageUrl': profileImageUrl,
      };

  static Owner fromMap(Map<String, dynamic> map) => Owner(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
        profileImageUrl: _sanitizeImageUrl(map['profileImageUrl']),
      );

  /// From the `owner:profiles!owner_id(...)` embed of [kStoreSelect].
  static Owner fromRow(Map<String, dynamic> r, {String fallbackId = ''}) => Owner(
        id: r['id'] ?? fallbackId,
        name: r['name'] ?? '',
        email: r['email'] ?? '',
        phone: r['phone_number'] ?? '',
        profileImageUrl: _sanitizeImageUrl(r['profile_image_url']),
      );
}

class Rating {
  final String userId;
  final double score;

  Rating({required this.userId, required this.score});

  Map<String, dynamic> toMap() => {'userId': userId, 'score': score};

  static Rating fromMap(Map<String, dynamic> map) => Rating(
        userId: map['userId'] ?? '',
        score: map['score']?.toDouble() ?? 0.0,
      );

  static Rating fromRow(Map<String, dynamic> r) =>
      Rating(userId: r['user_id'] ?? '', score: _num(r['rating']) ?? 0.0);
}

/// Placeholder kept for the unused `Store.orders` field.
class Order {}

class Orders {
  String id;
  String userId;
  String storeId;
  List<Product> products;
  double totalPrice;
  String status; // Pending, Processed, Shipped, Delivered
  Timestamp placedAt;
  String deliveryMethod;
  CustomUser? userDetails;
  Store? storeDetails;

  Orders({
    this.id = '',
    required this.userId,
    required this.storeId,
    required this.products,
    required this.totalPrice,
    this.status = 'Pending',
    required this.placedAt,
    required this.deliveryMethod,
    this.userDetails,
    this.storeDetails,
  });

  /// Select string for loading an order with its line items and buyer.
  static const String select =
      '*, order_items(*), buyer:profiles!user_id(id, name, email, phone_number, '
      'address, profile_image_url, role)';

  /// Columns of the `orders` table (line items are written to `order_items`).
  Map<String, dynamic> toRow() => {
        'user_id': userId,
        'store_id': storeId,
        'total_price': totalPrice,
        'status': status,
        'placed_at': placedAt.toIso(),
        'delivery_method': deliveryMethod,
      };

  List<Map<String, dynamic>> itemRows(String orderId) => products
      .map((p) => {
            'order_id': orderId,
            'product_id': p.id.isEmpty ? null : p.id,
            'name': p.name,
            'price': p.price,
            'image_url': p.imageUrl,
            'quantity': p.quantity,
          })
      .toList();

  /// Builds an order from a row loaded with [Orders.select].
  factory Orders.fromRow(Map<String, dynamic> r) {
    final buyer = r['buyer'] as Map<String, dynamic>?;
    return Orders(
      id: r['id'] ?? '',
      userId: r['user_id'] ?? '',
      storeId: r['store_id'] ?? '',
      products: ((r['order_items'] as List?) ?? [])
          .map((i) => Product(
                id: (i['product_id'] ?? '').toString(),
                name: i['name'] ?? '',
                price: _num(i['price']) ?? 0,
                imageUrl: _sanitizeImageUrl(i['image_url']),
                quantity: i['quantity'] ?? 1,
              ))
          .toList(),
      totalPrice: _num(r['total_price']) ?? 0.0,
      status: r['status'] ?? 'Pending',
      placedAt: Timestamp.parse(r['placed_at']),
      deliveryMethod: r['delivery_method'] ?? 'Unknown',
      userDetails: buyer != null ? CustomUser.fromRow(buyer) : null,
    );
  }

  Future<void> updateStatus(String storeId, String newStatus) async {
    try {
      await _db.from('orders').update({'status': newStatus}).eq('id', id);
    } catch (e) {
      print('Error updating order status: $e');
    }
  }
}

class YouTubeVideo {
  String id;
  String url;

  YouTubeVideo({required this.id, required this.url});

  Map<String, dynamic> toMap() => {'id': id, 'url': url};

  static YouTubeVideo fromMap(Map<String, dynamic> map) =>
      YouTubeVideo(id: (map['id'] ?? '').toString(), url: map['url'] ?? '');
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/Modal/types.dart';

export 'package:zing/Modal/types.dart';

SupabaseClient get _db => Supabase.instance.client;

/// PostgREST select string that loads a store with everything the UI shows.
const String kStoreSelect =
    '*, products(*), store_videos(*), store_ratings(user_id, rating), '
    'owner:profiles!owner_id(id, name, email, phone_number, profile_image_url)';

/// People can read only their own profile and those of people they trade or
/// chat with, so the `owner` embed of [kStoreSelect] comes back empty for most
/// customers. This fills in the public part (name, photo) through
/// `store_owner_info`, for the store rows that have no owner yet.
Future<void> fillStoreOwners(List rows) async {
  final missing = <String>[
    for (final r in rows)
      if (r['owner'] == null && r['id'] is String) r['id'] as String,
  ];
  if (missing.isEmpty) return;
  try {
    final owners = await _db.rpc('store_owner_info', params: {'p_store_ids': missing});
    final byStore = {for (final o in owners as List) o['store_id'] as String: o};
    for (final r in rows) {
      final o = byStore[r['id']];
      if (o != null) {
        r['owner'] = {
          'id': o['id'],
          'name': o['name'],
          'profile_image_url': o['profile_image_url'],
        };
      }
    }
  } catch (e) {
    print('Error loading store owners: $e');
  }
}

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

  bool get isAdmin => role == 'Admin';
  bool get isOwner => role == 'Owner';

  /// Store access lasts this many days after each registration payment.
  static const int accessDays = 30;

  /// Whole days of store access left (0 when it has run out), or null when
  /// no payment is loaded for this account. Based on the latest payment.
  int? subscriptionDaysLeft([DateTime? now]) {
    final list = payments;
    if (list == null || list.isEmpty) return null;
    final latest = list
        .map((p) => p.paymentDate.toDate())
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final remaining =
        latest.add(const Duration(days: accessDays)).difference(now ?? DateTime.now());
    if (remaining.isNegative) return 0;
    return (remaining.inMinutes / (24 * 60)).ceil();
  }

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

/// Opening and closing time for one weekday, in minutes after midnight.
class DayHours {
  final bool closed;
  final int open;
  final int close;

  const DayHours({this.closed = false, this.open = 9 * 60, this.close = 18 * 60});

  /// Same opening and closing time means open around the clock.
  bool get isAllDay => !closed && open == close;

  /// Closing time earlier than opening time means it closes after midnight.
  bool get isOvernight => !closed && close < open;

  DayHours copyWith({bool? closed, int? open, int? close}) => DayHours(
        closed: closed ?? this.closed,
        open: open ?? this.open,
        close: close ?? this.close,
      );

  Map<String, dynamic> toMap() => {
        'closed': closed,
        'open': _toClock(open),
        'close': _toClock(close),
      };

  static DayHours fromMap(dynamic raw) {
    if (raw is! Map) return const DayHours(closed: true);
    return DayHours(
      closed: raw['closed'] == true,
      open: _fromClock(raw['open']) ?? 9 * 60,
      close: _fromClock(raw['close']) ?? 18 * 60,
    );
  }

  static String _toClock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static int? _fromClock(dynamic value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  /// "9:00 AM" style label for [minutes] after midnight.
  static String label(int minutes) {
    final h24 = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final suffix = h24 < 12 ? 'AM' : 'PM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }
}

/// Whether a store is open at a given moment, with a short label to show.
class StoreOpenStatus {
  final bool isOpen;
  final String label;
  const StoreOpenStatus(this.isOpen, this.label);
}

/// A store's weekly opening hours (the `stores.opening_hours` jsonb column).
class OpeningHours {
  static const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _shortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// One entry per weekday, Monday first.
  final List<DayHours> days;

  OpeningHours(List<DayHours> days)
      : assert(days.length == 7),
        days = List.unmodifiable(days);

  /// Monday to Saturday 9 AM to 6 PM, closed on Sunday.
  factory OpeningHours.standard() => OpeningHours([
        for (int i = 0; i < 6; i++) const DayHours(),
        const DayHours(closed: true),
      ]);

  static OpeningHours? fromMap(dynamic raw) {
    if (raw is! Map || raw.isEmpty) return null;
    return OpeningHours([for (final key in dayKeys) DayHours.fromMap(raw[key])]);
  }

  Map<String, dynamic> toMap() => {
        for (int i = 0; i < 7; i++) dayKeys[i]: days[i].toMap(),
      };

  OpeningHours withDay(int index, DayHours hours) =>
      OpeningHours([for (int i = 0; i < 7; i++) i == index ? hours : days[i]]);

  StoreOpenStatus statusAt(DateTime now) {
    final t = now.hour * 60 + now.minute;
    final i = now.weekday - 1; // DateTime.monday == 1
    final today = days[i];
    final yesterday = days[(i + 6) % 7];

    // Still inside yesterday's after-midnight hours.
    if (yesterday.isOvernight && t < yesterday.close) {
      return StoreOpenStatus(true, 'Open · closes ${DayHours.label(yesterday.close)}');
    }
    if (!today.closed) {
      if (today.isAllDay) return const StoreOpenStatus(true, 'Open 24 hours');
      final openNow = today.isOvernight
          ? t >= today.open
          : (t >= today.open && t < today.close);
      if (openNow) {
        return StoreOpenStatus(true, 'Open · closes ${DayHours.label(today.close)}');
      }
      if (t < today.open) {
        return StoreOpenStatus(false, 'Closed · opens ${DayHours.label(today.open)}');
      }
    }
    for (int d = 1; d <= 7; d++) {
      final next = days[(i + d) % 7];
      if (next.closed) continue;
      final day = d == 1 ? 'tomorrow' : _shortNames[(i + d) % 7];
      final time = next.isAllDay ? '' : ' ${DayHours.label(next.open)}';
      return StoreOpenStatus(false, 'Closed · opens $day$time');
    }
    return const StoreOpenStatus(false, 'Closed');
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

  /// False hides the store from customers (`stores.is_active`).
  bool isActive;

  /// Weekly opening hours set by the owner; null when never set.
  OpeningHours? openingHours;

  /// Owner switch to close the store for now regardless of the hours.
  bool temporarilyClosed;

  /// Average and count of [ratings], worked out when the store is loaded.
  double? ratingAvg;
  int? ratingCount;

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
    this.isActive = true,
    this.openingHours,
    this.temporarilyClosed = false,
    this.ratingAvg,
    this.ratingCount,
  });

  /// Open/closed right now, or null when the owner has not set any hours.
  StoreOpenStatus? openStatus([DateTime? now]) {
    if (temporarilyClosed) {
      return const StoreOpenStatus(false, 'Temporarily closed');
    }
    return openingHours?.statusAt(now ?? DateTime.now());
  }

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
        // opening_hours, temporarily_closed and is_active are left out on
        // purpose: screens that rebuild a Store to save it would wipe them.
        // StoreProvider.updateStoreHours writes the hours.
      };

  /// Builds a store from a row loaded with [kStoreSelect].
  static Store fromRow(Map<String, dynamic> r) {
    final ownerRow = (r['owner'] as Map<String, dynamic>?) ?? const {};
    final ratings = ((r['store_ratings'] as List?) ?? [])
        .map((m) => Rating.fromRow(m as Map<String, dynamic>))
        .toList();
    return Store(
      isActive: r['is_active'] ?? true,
      openingHours: OpeningHours.fromMap(r['opening_hours']),
      temporarilyClosed: r['temporarily_closed'] ?? false,
      ratingCount: ratings.length,
      ratingAvg: ratings.isEmpty
          ? null
          : ratings.fold<double>(0, (s, x) => s + x.score) / ratings.length,
      id: r['id'],
      phoneNumber: r['phone_number'] ?? '',
      name: r['name'] ?? '',
      registrationsAmount: _num(r['registration_amount']),
      description: r['description'] ?? '',
      ratings: ratings,
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
  /// Stock at or below this count is flagged to the store owner.
  static const int lowStockThreshold = 5;

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

  /// A product can be bought only when the owner marked it available and
  /// there is stock left.
  bool get inStock => isAvailable && quantity > 0;

  /// On sale but nearly gone: worth restocking.
  bool get lowStock => isAvailable && quantity > 0 && quantity <= lowStockThreshold;

  /// Price after the discount percentage, if any.
  double get effectivePrice => (discount != null && discount! > 0)
      ? price * (1 - discount! / 100)
      : price;

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

/// The steps an order moves through. The store owner advances the status;
/// the customer may cancel only while it is still [pending] (enforced by the
/// `guard_order_update` trigger).
class OrderStatus {
  OrderStatus._();

  static const pending = 'Pending';
  static const processed = 'Processed';
  static const shipped = 'Shipped';
  static const delivered = 'Delivered';
  static const cancelled = 'Cancelled';

  /// The normal path, in order.
  static const flow = [pending, processed, shipped, delivered];

  static const all = [...flow, cancelled];

  static bool isFinal(String status) => status == delivered || status == cancelled;

  /// The next step after [status], or null when there is none.
  static String? next(String status) {
    final i = flow.indexOf(status);
    return (i >= 0 && i < flow.length - 1) ? flow[i + 1] : null;
  }

  /// True when the store may move an order from [from] to [to].
  static bool canMove(String from, String to) {
    if (from == to || isFinal(from)) return false;
    if (to == cancelled) return true;
    return next(from) == to;
  }

  /// Wording shown to the customer, which depends on how they get the order.
  static String customerLabel(String status, String deliveryMethod) {
    final pickup = deliveryMethod.toLowerCase().contains('pickup');
    switch (status) {
      case pending:
        return 'Order placed';
      case processed:
        return 'Being prepared';
      case shipped:
        return pickup ? 'Ready for pickup' : 'Out for delivery';
      case delivered:
        return pickup ? 'Collected' : 'Delivered';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}

/// One product in an order with the number of units ordered.
class OrderLine {
  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final String? imageUrl;

  const OrderLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
  });

  double get total => unitPrice * quantity;
}

/// One entry in an order's status history (`order_status_history`).
class OrderStatusChange {
  final String status;
  final Timestamp at;
  const OrderStatusChange(this.status, this.at);
}

class Orders {
  String id;
  String userId;
  String storeId;
  String storeName;

  /// Line items. Each row's [Product.quantity] is the number of units
  /// ordered (the cart writes one row per unit). Use [lines] for a summary.
  List<Product> products;
  double totalPrice; // Includes the delivery fee
  double deliveryFee;
  String? deliveryAddress;
  String status; // See [OrderStatus]
  Timestamp placedAt;
  String deliveryMethod;
  CustomUser? userDetails;
  Store? storeDetails;
  List<OrderStatusChange> statusHistory;

  /// 'customer' or 'store' when the order was cancelled.
  String? cancelledBy;

  Orders({
    this.id = '',
    required this.userId,
    required this.storeId,
    this.storeName = '',
    required this.products,
    required this.totalPrice,
    this.deliveryFee = 0.0,
    this.deliveryAddress,
    this.status = OrderStatus.pending,
    required this.placedAt,
    required this.deliveryMethod,
    this.userDetails,
    this.storeDetails,
    this.statusHistory = const [],
    this.cancelledBy,
  });

  /// Select string for loading an order with its line items, buyer, store
  /// name and status history.
  static const String select =
      '*, order_items(*), buyer:profiles!user_id(id, name, email, phone_number, '
      'address, profile_image_url, role), store:stores(name, image_url), '
      'order_status_history(status, changed_at)';

  static int _units(Product p) => p.quantity > 0 ? p.quantity : 1;

  /// Products grouped by item, with the number of units of each.
  List<OrderLine> get lines {
    final byKey = <String, OrderLine>{};
    for (final product in products) {
      final key = product.id.isNotEmpty ? product.id : product.name;
      final existing = byKey[key];
      byKey[key] = OrderLine(
        productId: product.id,
        name: product.name,
        unitPrice: product.price,
        quantity: (existing?.quantity ?? 0) + _units(product),
        imageUrl: product.imageUrl,
      );
    }
    return byKey.values.toList();
  }

  int get itemCount => products.fold(0, (sum, p) => sum + _units(p));

  bool get isHomeDelivery => deliveryMethod.toLowerCase().contains('delivery');

  /// Customers can cancel only before the store starts on the order.
  bool get canCustomerCancel => status == OrderStatus.pending;

  /// When the order reached [status], if recorded.
  Timestamp? reachedAt(String status) {
    for (final change in statusHistory.reversed) {
      if (change.status == status) return change.at;
    }
    return status == OrderStatus.pending ? placedAt : null;
  }

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
    final store = r['store'] as Map<String, dynamic>?;
    final address = (r['delivery_address'] as String? ?? '').trim();
    final history = ((r['order_status_history'] as List?) ?? [])
        .whereType<Map>()
        .where((h) => h['status'] is String && h['changed_at'] != null)
        .map((h) => OrderStatusChange(h['status'] as String, Timestamp.parse(h['changed_at'])))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return Orders(
      id: r['id'] ?? '',
      userId: r['user_id'] ?? '',
      storeId: r['store_id'] ?? '',
      storeName: (store?['name'] as String?) ?? '',
      deliveryFee: _num(r['delivery_fee']) ?? 0.0,
      deliveryAddress: address.isEmpty ? null : address,
      statusHistory: history,
      cancelledBy: r['cancelled_by'] as String?,
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

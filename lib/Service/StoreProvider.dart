import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';

class StoreProvider with ChangeNotifier {
  List<Store> _stores = [];
  bool isLoading = true;

  List<Store> get stores => _stores;

  /// Stores customers may see (`stores.is_active`).
  List<Store> get activeStores => _stores.where((s) => s.isActive).toList();

  /// Saves the owner's weekly hours and the "closed for now" switch.
  Future<void> updateStoreHours(
    String storeId, {
    OpeningHours? openingHours,
    required bool temporarilyClosed,
  }) async {
    await _db.from('stores').update({
      'opening_hours': openingHours?.toMap(),
      'temporarily_closed': temporarilyClosed,
    }).eq('id', storeId);
    for (final s in _stores) {
      if (s.id == storeId) {
        s.openingHours = openingHours;
        s.temporarilyClosed = temporarilyClosed;
      }
    }
    notifyListeners();
  }

  SupabaseClient get _db => Supabase.instance.client;

  StoreProvider() {
    fetchStores();
  }

  Store? _selectedStore;
  Store? get selectedStore => _selectedStore;

  void selectStore(Store store) {
    _selectedStore = store;
    notifyListeners();
  }

  void _notifyLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  /// Loads every store with its products, videos, ratings and owner.
  Future<void> fetchStores() async {
    isLoading = true;
    _notifyLater();

    try {
      final rows = await _db.from('stores').select(kStoreSelect).order('created_at');
      await fillStoreOwners(rows as List);
      final fetched = <Store>[];
      for (final row in rows) {
        try {
          fetched.add(Store.fromRow(row));
        } catch (e) {
          print('Error parsing store ${row['id']}: $e');
        }
      }
      _stores = fetched;
    } catch (e) {
      print('Error fetching stores: $e');
    } finally {
      isLoading = false;
      _notifyLater();
    }
  }

  Future<List<Product>> fetchProductsForStore(String storeId) async {
    final rows = await _db.from('products').select().eq('store_id', storeId);
    return (rows as List).map((r) => Product.fromRow(r)).toList();
  }

  Future<Store?> getStoreById(String storeId) async {
    if (storeId.isEmpty) {
      print('Error: storeId is empty');
      return null;
    }
    try {
      final row =
          await _db.from('stores').select(kStoreSelect).eq('id', storeId).maybeSingle();
      if (row == null) return null;
      await fillStoreOwners([row]);
      return Store.fromRow(row);
    } catch (e) {
      print('Error fetching store for storeId $storeId: $e');
      throw Exception('Failed to fetch store data.');
    }
  }

  Future<Store?> fetchStore(String storeId) async {
    if (storeId.isEmpty) {
      print('Cannot fetch store: Store ID is empty');
      return null;
    }
    try {
      return await getStoreById(storeId);
    } catch (e) {
      print('Error fetching store data: $e');
      return null;
    }
  }

  Future<void> addStore(Store newStore, CustomUserProvider userProvider) async {
    try {
      final row = await _db.from('stores').insert(newStore.toRow()).select('id').single();
      newStore.id = row['id'] as String;
      await userProvider.fetchUserDetails();
      await fetchStores();
    } catch (e) {
      print('Error adding store: $e');
    }
  }

  Future<void> editStore(
      String storeId, Store updatedStore, CustomUserProvider userProvider) async {
    try {
      final row = updatedStore.toRow()
        ..remove('id')
        ..remove('owner_id'); // ownership never changes through an edit
      await _db.from('stores').update(row).eq('id', storeId);
      await userProvider.fetchUserDetails();
      await fetchStores();
    } catch (e) {
      print('Error editing store: $e');
    }
  }

  /// Deletes a store; products, videos and ratings cascade in the database.
  Future<void> deleteStore(String storeId, CustomUserProvider userProvider) async {
    try {
      if (storeId.isEmpty) {
        throw Exception('Store ID cannot be empty or null.');
      }
      await _db.from('stores').delete().eq('id', storeId);
      if (userProvider.user?.store?.id == storeId) {
        userProvider.user!.store = null;
      }
      await fetchStores();
    } catch (e) {
      print('Error deleting store: $e');
    }
  }

  Future<void> addProduct(String storeId, Product newProduct,
      CustomUserProvider userProvider, BuildContext context) async {
    try {
      if (storeId.isEmpty) {
        throw Exception('Store ID cannot be empty.');
      }
      final row = await _db
          .from('products')
          .insert(newProduct.toRow(storeId)..remove('id'))
          .select('id')
          .single();
      newProduct.id = row['id'] as String;

      await userProvider.fetchUserDetails();
      await fetchStores();
    } catch (e) {
      print('Error adding product: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product: $e')),
        );
      }
    }
  }

  Future<void> editProduct(
      String storeId, Product updatedProduct, CustomUserProvider userProvider) async {
    try {
      final row = updatedProduct.toRow(storeId)..remove('id');
      await _db.from('products').update(row).eq('id', updatedProduct.id);
      await userProvider.fetchUserDetails();
      fetchStores();
    } catch (e) {
      print('Error editing product: $e');
    }
  }

  Future<void> deleteProduct(
      String storeId, String productId, CustomUserProvider userProvider) async {
    try {
      await _db.from('products').delete().eq('id', productId);
      await userProvider.fetchUserDetails();
      fetchStores();
    } catch (e) {
      print('Error deleting product: $e');
    }
  }

  Future<List<Payment>> fetchPaymentsForStoreByOwner(String userId, String storeId) async {
    try {
      final rows = await _db
          .from('payments')
          .select()
          .eq('user_id', userId)
          .eq('store_id', storeId);
      return (rows as List).map((r) => Payment.fromRow(r)).toList();
    } catch (e) {
      print('Error fetching payments for user $userId: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------- videos

  Future<void> addVideo(String storeId, String videoUrl) async {
    try {
      final videoId = YoutubePlayer.convertUrlToId(videoUrl);
      if (videoId != null) {
        await _db.from('store_videos').insert({'store_id': storeId, 'url': videoUrl});
        notifyListeners();
      } else {
        print('Invalid YouTube URL');
      }
    } catch (e) {
      print('Error adding video: $e');
    }
  }

  /// [videoId] is the id of the `store_videos` row (see [YouTubeVideo.id]).
  Future<void> editVideo(String storeId, String videoId, String newUrl) async {
    try {
      await _db
          .from('store_videos')
          .update({'url': newUrl})
          .eq('id', videoId)
          .eq('store_id', storeId);
      notifyListeners();
    } catch (e) {
      print('Error editing video: $e');
    }
  }

  Future<void> deleteVideo(String storeId, YouTubeVideo video) async {
    try {
      await _db.from('store_videos').delete().eq('id', video.id).eq('store_id', storeId);
      notifyListeners();
    } catch (e) {
      print('Error deleting video: $e');
    }
  }

  // ---------------------------------------------------------------- owner / chats

  Future<CustomUser?> fetchOwnerByStoreId(String storeId) async {
    try {
      final store =
          await _db.from('stores').select('owner_id').eq('id', storeId).maybeSingle();
      final ownerId = store?['owner_id'] as String?;
      if (ownerId == null || ownerId.isEmpty) {
        print('No owner found for storeId: $storeId');
        return null;
      }
      final owner = await _db.from('profiles').select().eq('id', ownerId).maybeSingle();
      return owner == null ? null : CustomUser.fromRow(owner);
    } catch (e) {
      print('Error fetching owner by storeId: $e');
      return null;
    }
  }

  Future<String?> findChatId(String customerId, String storeId) async {
    final row = await _db
        .from('chats')
        .select('id')
        .eq('user_id', customerId)
        .eq('store_id', storeId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<List<Map<String, dynamic>>> fetchUserChatsForOwner(String storeId) async {
    try {
      final rows = await _db
          .from('chats')
          .select()
          .eq('store_id', storeId)
          .order('last_updated', ascending: false);
      return (rows as List)
          .map((r) => {
                'chatId': r['id'],
                'customerId': r['user_id'],
                'lastMessage': r['last_message'] ?? '',
                'lastUpdated': Timestamp.parse(r['last_updated']),
              })
          .toList();
    } catch (e) {
      print('Error fetching chats for owner: $e');
      return [];
    }
  }
}

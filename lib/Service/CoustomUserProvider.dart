import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/ApiClient.dart';

class CustomUserProvider with ChangeNotifier {
  CustomUser? currentUser;
  bool _isLoading = false;
  List<Payment> _payments = [];
  List<Payment> get payments => _payments;
  CustomUser? get user => currentUser;
  bool get isLoading => _isLoading;
  List<CustomUser> _users = [];
  List<CustomUser> get users => _users;

  SupabaseClient get _db => Supabase.instance.client;
  GoTrueClient get _auth => _db.auth;

  // Live stream of the profiles table, used by the admin screens.
  StreamSubscription<List<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<AuthState>? _authSub;

  CustomUserProvider() {
    _initializeUser();
  }

  void _notifyLater() {
    // Post-frame callback prevents semantics assertion errors during navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> updatePaymentStatusAndStoreAccess(CustomUser user, bool accessStatus) async {
    try {
      user.storeAccess = accessStatus;

      // Mark the latest payment as completed.
      final latest = await _db
          .from('payments')
          .select('id')
          .eq('user_id', user.id)
          .order('paid_at', ascending: false)
          .limit(1);
      if ((latest as List).isNotEmpty) {
        await _db.from('payments').update({
          'payment_status': 'Completed',
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', latest.first['id']);
      } else if (accessStatus) {
        // Nothing was recorded yet. Store access ends 30 days after the latest
        // payment (expire_store_access), so approving must leave a payment.
        final store = await _db
            .from('stores')
            .select('id, registration_amount')
            .eq('owner_id', user.id)
            .limit(1)
            .maybeSingle();
        await _db.from('payments').insert({
          'user_id': user.id,
          'store_id': store?['id'],
          'amount': store?['registration_amount'] ?? 0,
          'items': 'Store subscription (approved by admin)',
          'payment_status': 'Completed',
        });
      }

      await _db
          .from('profiles')
          .update({'store_access': accessStatus, 'has_paid': true}).eq('id', user.id);

      notifyListeners();
    } catch (e) {
      print('Error updating payment status or store access: $e');
      rethrow;
    }
  }

  Future<void> _initializeUser() async {
    _isLoading = true;
    _notifyLater();

    // Load the signed-in user's own data; the full user list is admin-only.
    _authSub = _auth.onAuthStateChange.listen((AuthState state) async {
      try {
        if (state.session == null) {
          currentUser = null;
          _stopUsersListener();
          return;
        }
        final me = await fetchUserDetails();
        await fetchPaymentsForCurrentUser();
        if (me?.role == 'Admin') {
          await fetchUsers();
        } else {
          _stopUsersListener();
        }
      } catch (e) {
        print('Error during initialization: $e');
      } finally {
        _isLoading = false;
        _notifyLater();
      }
    });
  }

  void _stopUsersListener() {
    _usersSub?.cancel();
    _usersSub = null;
    _users = [];
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void refreshUserData() {
    fetchUserDetails();
  }


  Future<List<String>> _favoritesOf(String userId) async {
    final rows = await _db.from('user_favorites').select('store_id').eq('user_id', userId);
    return (rows as List).map((r) => r['store_id'] as String).toList();
  }

  Future<Store?> _storeOf(String ownerId) async {
    final rows = await _db
        .from('stores')
        .select(kStoreSelect)
        .eq('owner_id', ownerId)
        .order('created_at')
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return Store.fromRow(rows.first);
  }

  Future<CustomUser?> _loadUser(String userId) async {
    final row = await _db.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    final favorites = await _favoritesOf(userId);
    final store = row['role'] == 'Owner' ? await _storeOf(userId) : null;
    return CustomUser.fromRow(row, store: store, favorites: favorites);
  }

  /// Loads every profile and keeps the list live. Admins only.
  Future<void> fetchUsers() async {
    if (currentUser?.role != 'Admin') {
      _stopUsersListener();
      return;
    }
    _isLoading = true;
    _notifyLater();

    try {
      await _usersSub?.cancel();
      _usersSub = _db.from('profiles').stream(primaryKey: ['id']).listen((rows) {
        _users = rows.map((r) => CustomUser.fromRow(r)).toList();
        _isLoading = false;
        _notifyLater();
      }, onError: (error) {
        print('Error in users stream: $error');
        _isLoading = false;
        _notifyLater();
      });
    } catch (e) {
      print('Error setting up users listener: $e');
      _isLoading = false;
      _notifyLater();
    }
  }

  Future<void> fetchPaymentsForCurrentUser() async {
    if (currentUser == null) {
      print('No current user set.');
      return;
    }
    try {
      final rows = await _db
          .from('payments')
          .select()
          .eq('user_id', currentUser!.id)
          .order('paid_at', ascending: false);
      _payments = (rows as List).map((r) => Payment.fromRow(r)).toList();
      _notifyLater();
    } catch (e) {
      print('Error fetching payments: $e');
    }
  }

  Future<void> addPaymentToCurrentUser(Payment payment) async {
    if (currentUser == null) {
      print('No current user set.');
      return;
    }
    try {
      final row = await _db
          .from('payments')
          .insert(payment.toRow(currentUser!.id))
          .select('id')
          .single();
      payment.paymentId = row['id'] as String;
      await fetchUserDetails();
    } catch (e) {
      print('Error adding payment: $e');
    }
  }

  Future<CustomUser?> fetchUserDetails() async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      print('No user is logged in.');
      return null;
    }
    try {
      final loaded = await _loadUser(authUser.id);
      if (loaded == null) {
        print('User data not found.');
        return null;
      }
      currentUser = loaded;
      _notifyLater();
      return currentUser;
    } catch (e) {
      print('Error fetching user details: $e');
      return null;
    }
  }

  /// Creates the current user's store. Products and videos are written to
  /// their own tables.
  Future<void> addStoreToUser(Store newStore) async {
    if (currentUser == null) {
      print('No current user set.');
      return;
    }
    try {
      final row = await _db
          .from('stores')
          .insert(newStore.toRow()..['owner_id'] = currentUser!.id)
          .select('id')
          .single();
      final storeId = row['id'] as String;
      newStore.id = storeId;

      if (newStore.products.isNotEmpty) {
        await _db
            .from('products')
            .insert(newStore.products.map((p) => p.toRow(storeId)..remove('id')).toList());
      }
      final videos = newStore.videos ?? [];
      if (videos.isNotEmpty) {
        await _db
            .from('store_videos')
            .insert(videos.map((v) => {'store_id': storeId, 'url': v.url}).toList());
      }

      currentUser!.store = await _storeOf(currentUser!.id) ?? newStore;
      notifyListeners();
    } catch (e) {
      print('Error adding store to user: $e');
    }
  }

  void addFavoriteStore(String storeId) {
    if (currentUser != null && !currentUser!.favorites!.contains(storeId)) {
      currentUser!.addFavorite(storeId);
      _db
          .from('user_favorites')
          .upsert({'user_id': currentUser!.id, 'store_id': storeId})
          .catchError((e) => print('Error adding favorite: $e'));
      notifyListeners();
    }
  }

  void removeFavoriteStore(String storeId) {
    if (currentUser != null && currentUser!.favorites!.contains(storeId)) {
      currentUser!.removeFavorite(storeId);
      _db
          .from('user_favorites')
          .delete()
          .eq('user_id', currentUser!.id)
          .eq('store_id', storeId)
          .catchError((e) => print('Error removing favorite: $e'));
      notifyListeners();
    }
  }

  Future<CustomUser?> fetchUserById(String userId) async {
    try {
      return await _loadUser(userId);
    } catch (e) {
      print('Error fetching user by ID: $e');
      return null;
    }
  }

  Future<CustomUser?> getUserById(String userId) => fetchUserById(userId);

  bool isFavoriteStore(String storeId) {
    return currentUser?.favorites!.contains(storeId) ?? false;
  }

  void monitorAuthState() {
    // The provider already listens to auth changes in _initializeUser.
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      currentUser = null;
      _payments = [];
      _stopUsersListener();
      _notifyLater();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Updates the current user's own profile fields.
  Future<void> saveUserDetails(CustomUser user) async {
    try {
      final row = user.toRow();
      // Only admins may change these; the database ignores them otherwise.
      row.remove('role');
      row.remove('store_access');
      row.remove('has_paid');
      await _db.from('profiles').upsert(row);
      currentUser = user;
      _notifyLater();
    } catch (e) {
      print('Error saving user details: $e');
    }
  }

  /// Deletes an account. The Node API removes the auth user and the database
  /// cascades to the profile, store, products and orders.
  Future<void> deleteUser(String userId, {bool isOwner = false, String? storeId}) async {
    if (_auth.currentUser == null) {
      print('No signed-in user.');
      return;
    }
    try {
      await ApiClient.delete('/users/$userId');
      _users.removeWhere((user) => user.id == userId);
      notifyListeners();
    } catch (e) {
      print('Error deleting user: $e');
    }
  }

  /// Admin creates an account with a role (the admin stays signed in).
  Future<void> addUser({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    required String role,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.post('/admin/users', {
        'email': email,
        'password': password,
        'name': name,
        'phone_number': phoneNumber,
        'role': role,
      });
    } catch (e) {
      print('Error adding new user: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAdmin({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) =>
      addUser(email: email, password: password, name: name, phoneNumber: phoneNumber, role: 'Admin');

  Future<void> addOwner({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) =>
      addUser(email: email, password: password, name: name, phoneNumber: phoneNumber, role: 'Owner');

  Future<void> addRegularUser({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) =>
      addUser(email: email, password: password, name: name, phoneNumber: phoneNumber, role: 'User');

  Future<void> changePassword(String newPassword) async {
    try {
      if (_auth.currentUser == null) {
        print('No user is logged in to change the password.');
        return;
      }
      await _auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      print('Error changing password: $e');
      rethrow;
    }
  }
}

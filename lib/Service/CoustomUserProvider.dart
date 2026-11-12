import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CustomUserProvider with ChangeNotifier {
  CustomUser? currentUser;
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Payment> _payments = [];
  List<Payment> get payments => _payments;
  CustomUser? get user => currentUser;
  bool get isLoading => _isLoading;
  List<CustomUser> _users = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<CustomUser> get users => _users;

  // Live listener on the whole users collection. Only admins may run it
  // (Firestore rules deny listing users to everyone else).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<User?>? _authSub;

  CustomUserProvider() {
    _initializeUser();
  }

  Future<void> updatePaymentStatusAndStoreAccess(CustomUser user, bool accessStatus) async {
    try {
      // Update `storeAccess` field
      user.storeAccess = accessStatus;

      // Fetch the latest payment record and update it
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('payments')
          .orderBy('paymentDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var paymentDoc = snapshot.docs.first;
        // Update the payment document with current payment status and the current date
        await paymentDoc.reference.update({
          'paymentStatus': 'Completed',
          'paymentDate': FieldValue.serverTimestamp(), // Sets the current timestamp in Firestore
        });
      }

      // Update Firestore to reflect the changes
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update({'storeAccess': accessStatus, 'hasPaid': true});

      notifyListeners();
    } catch (e) {
      print('Error updating payment status or store access: $e');
      rethrow;
    }
  }

  // Initialize the user data and payments concurrently
  Future<void> _initializeUser() async {
    _isLoading = true;
    // Use post-frame callback to prevent semantics assertion errors during navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    // Load the signed-in user's own data. The full user list is only loaded
    // for admins; guests and normal users never read other users' documents.
    _authSub = _auth.authStateChanges().listen((User? firebaseUser) async {
      try {
        if (firebaseUser == null) {
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
        print("Error during initialization: $e");
      } finally {
        _isLoading = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
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
    fetchUserDataFromFirestore();  // Call to re-fetch data from Firestore
  }

  // Fetch the current logged-in user's details from Firestore
  Future<void> fetchUserDataFromFirestore() async {
    User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      print("No user is logged in.");
      return;
    }

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
      final DocumentSnapshot<Map<String, dynamic>> userDoc = await userRef.get();

      if (userDoc.exists && userDoc.data() != null) {
        currentUser = CustomUser.fromDocument(userDoc);  // Update the current user
        // Use post-frame callback to prevent semantics assertion errors during navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();  // Notify listeners about the data change
        });
      } else {
        print("User data not found.");
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }
  }

  // FIXED: Fetch all users from Firestore with proper loading state management
  Future<void> fetchUsers() async {
    if (currentUser?.role != 'Admin') {
      // Only admins can list users.
      _stopUsersListener();
      return;
    }
    print("Starting to fetch users...");
    _isLoading = true;
    // Use post-frame callback to prevent semantics assertion errors during navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      // Use snapshots() to listen for real-time updates
      await _usersSub?.cancel();
      _usersSub = FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
        print("Received ${snapshot.docs.length} user documents from Firestore");

        _users = snapshot.docs.map((doc) {
          try {
            final userData = doc.data() as Map<String, dynamic>;
            print("Processing user: ${userData['name']} with role: ${userData['role']}");

            // Create user from document
            final user = CustomUser.fromDocument(doc);

            // Debug: Print user details
            print("Created CustomUser - Name: ${user.name}, Role: ${user.role}, ID: ${user.id}");

            return user;
          } catch (e) {
            print("Error processing user document ${doc.id}: $e");
            print("Document data: ${doc.data()}");
            // Return a placeholder user or skip this user
            return null;
          }
        }).where((user) => user != null).cast<CustomUser>().toList();

        // Debug: Print role distribution
        final roleCount = <String, int>{};
        for (final user in _users) {
          final role = user.role ?? 'No Role';
          roleCount[role] = (roleCount[role] ?? 0) + 1;
        }
        print("Role distribution: $roleCount");

        _isLoading = false; // Set loading to false after data is processed
        // Use post-frame callback to prevent semantics assertion errors during navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners(); // Notify listeners when data changes
        });
      }, onError: (error) {
        print("Error in users stream: $error");
        _isLoading = false;
        // Use post-frame callback to prevent semantics assertion errors
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      });
    } catch (e) {
      print("Error setting up users listener: $e");
      _isLoading = false;
      // Use post-frame callback to prevent semantics assertion errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // Fetch payments for the current user
  Future<void> fetchPaymentsForCurrentUser() async {
    if (currentUser == null) {
      print('No current user set.');
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> paymentsSnapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.id)
          .collection('payments')
          .get();

      _payments = paymentsSnapshot.docs.map((doc) {
        return Payment.fromMap(doc.data());
      }).toList();

      // Use post-frame callback to prevent semantics assertion errors during navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      print('Error fetching payments: $e');
    }
  }

  // Add payment to the current user's subcollection
  Future<void> addPaymentToCurrentUser(Payment payment) async {
    if (currentUser == null) {
      print('No current user set.');
      return;
    }

    try {
      DocumentReference paymentRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.id)
          .collection('payments')
          .add(payment.toMap());

      payment.paymentId = paymentRef.id;

      // Re-fetch the updated user data
      await fetchUserDetails();

      print("Payment added successfully and user details updated.");
    } catch (e) {
      print('Error adding payment: $e');
    }
  }

  // Fetch the current logged-in user's details
  Future<CustomUser?> fetchUserDetails() async {
    User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      print("No user is logged in.");
      return null;
    }

    try {
      final userRef =
      FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
      final DocumentSnapshot<Map<String, dynamic>> userDoc = await userRef.get();

      if (userDoc.exists && userDoc.data() != null) {
        currentUser = CustomUser.fromDocument(userDoc);
        // Use post-frame callback to prevent semantics assertion errors during navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return currentUser;
      } else {
        print("User data not found.");
        return null;
      }
    } catch (e) {
      print("Error fetching user details: $e");
      return null;
    }
  }

  // Add a store to the current user
  Future<void> addStoreToUser(Store newStore) async {
    if (currentUser == null) {
      print("No current user set.");
      return;
    }

    try {
      DocumentReference storeRef =
      await FirebaseFirestore.instance.collection('stores').add(newStore.toMap());
      newStore.id = storeRef.id;

      currentUser!.store = newStore;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.id)
          .update({'store': newStore.toMap()});

      notifyListeners();
    } catch (e) {
      print("Error adding store to user: $e");
    }
  }

  // Handle favorite stores
  void addFavoriteStore(String storeId) {
    if (currentUser != null && !currentUser!.favorites!.contains(storeId)) {
      currentUser!.addFavorite(storeId);
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.id)
          .update({'favorites': currentUser!.favorites});
      notifyListeners();
    }
  }

  void removeFavoriteStore(String storeId) {
    if (currentUser != null && currentUser!.favorites!.contains(storeId)) {
      currentUser!.removeFavorite(storeId);
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.id)
          .update({'favorites': currentUser!.favorites});
      notifyListeners();
    }
  }

  // Fetch a user by their user ID
  Future<CustomUser?> fetchUserById(String userId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data() != null) {
        return CustomUser.fromDocument(userDoc);
      } else {
        print("User not found for ID: $userId");
        return null;
      }
    } catch (e) {
      print("Error fetching user by ID: $e");
      return null;
    }
  }

  bool isFavoriteStore(String storeId) {
    return currentUser?.favorites!.contains(storeId) ?? false;
  }

  // Monitor authentication state changes
  void monitorAuthState() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        print("User is currently signed out.");
        currentUser = null;
        // Use post-frame callback to prevent semantics assertion errors during navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      } else {
        print("User is signed in.");
        fetchUserDetails();
      }
    });
  }

  // Sign out the user
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      currentUser = null;
      _stopUsersListener();
      // Use post-frame callback to prevent semantics assertion errors during navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Save user details in Firestore
  Future<void> saveUserDetails(CustomUser user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set(user.toMap(), SetOptions(merge: true));
      currentUser = user;
      // Use post-frame callback to prevent semantics assertion errors during navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      print("Error saving user details: $e");
    }
  }

  Future<void> deleteUser(String userId, {bool isOwner = false, String? storeId}) async {
    User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      print("User found: ${firebaseUser.uid}");
      try {
        // Step 1: Delete the user's store if the user is an owner
        if (isOwner && storeId != null) {
          await _deleteStore(storeId);
        }

        // Step 2: Delete user from Firestore
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();

        // Step 3: Delete user from Firebase Authentication
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('deleteUser');
        await callable.call({
          "uid": userId,
        });

        _users.removeWhere((user) => user.id == userId);
        notifyListeners();
      } catch (e) {
        print('Error deleting user: $e');
      }
    } else {
      print("User not found in Firebase Authentication.");
    }
  }

  Future<void> _deleteStore(String storeId) async {
    try {
      // Step 1: Delete all the products associated with the store
      QuerySnapshot productsSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('products')
          .get();

      for (var productDoc in productsSnapshot.docs) {
        await productDoc.reference.delete();
      }

      // Step 2: Delete the store document from Firestore
      await FirebaseFirestore.instance.collection('stores').doc(storeId).delete();

      print('Store deleted successfully');
    } catch (e) {
      print('Error deleting store: $e');
    }
  }

  // ENHANCED: Add user with proper role validation
  Future<void> addUser({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    required String role, // Adding role as a required parameter
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      print("Creating user with role: $role");

      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Construct a new CustomUser object
      CustomUser newUser = CustomUser(
        id: userCredential.user!.uid,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        address: '', // Default values can be changed as needed
        profileImageUrl: '', // Default profile image (or set your own)
        role: role, // Role set from input
      );

      print("Adding user to Firestore with data: ${newUser.toMap()}");

      // Add user details to Firestore
      await FirebaseFirestore.instance.collection('users').doc(newUser.id).set(newUser.toMap());

      print("User created successfully with ID: ${newUser.id} and role: ${newUser.role}");

      // Set the new user to the provider's state
      currentUser = newUser;
    } catch (e) {
      print("Error adding new user: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch a user by their user ID
  Future<CustomUser?> getUserById(String userId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data() != null) {
        return CustomUser.fromDocument(userDoc);
      } else {
        print("User not found for ID: $userId");
        return null;
      }
    } catch (e) {
      print("Error fetching user by ID: $e");
      return null;
    }
  }

  // Add admin with explicit role
  Future<void> addAdmin({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    await addUser(
      email: email,
      password: password,
      name: name,
      phoneNumber: phoneNumber,
      role: 'Admin',
    );
  }

  // ADDED: Method to add Owner specifically
  Future<void> addOwner({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    await addUser(
      email: email,
      password: password,
      name: name,
      phoneNumber: phoneNumber,
      role: 'Owner',
    );
  }

  // ADDED: Method to add regular User specifically
  Future<void> addRegularUser({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    await addUser(
      email: email,
      password: password,
      name: name,
      phoneNumber: phoneNumber,
      role: 'User',
    );
  }

  // Change password for the current user
  Future<void> changePassword(String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        await user.reload(); // Reload user to apply changes
        print("Password updated successfully.");
      } else {
        print("No user is logged in to change the password.");
      }
    } catch (e) {
      if (e.toString().contains('requires-recent-login')) {
        print("Error: The user needs to reauthenticate before changing the password.");
      } else {
        print("Error changing password: $e");
      }
      rethrow;
    }
  }

  // ADDED: Debug method to check Firestore data
  Future<void> debugFirestoreData() async {
    try {
      print("=== DEBUGGING FIRESTORE USER DATA ===");

      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      print("Total documents in users collection: ${snapshot.docs.length}");

      for (final doc in snapshot.docs) {
        final data = doc.data();
        print("---");
        print("Document ID: ${doc.id}");
        print("Name: ${data['name']}");
        print("Email: ${data['email']}");
        print("Role: ${data['role']} (Type: ${data['role']?.runtimeType})");
        print("Full document: $data");
      }

      print("=== END DEBUG ===");
    } catch (e) {
      print("Error debugging Firestore data: $e");
    }
  }
}
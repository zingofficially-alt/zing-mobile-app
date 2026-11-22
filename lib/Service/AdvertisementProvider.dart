import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/Service/StorageService.dart';

class Advertisement {
  final String imageUrl;
  final String description;

  Advertisement({required this.imageUrl, required this.description});

  factory Advertisement.fromRow(Map<String, dynamic> r) => Advertisement(
        imageUrl: r['image_url'] ?? '',
        description: r['description'] ?? '',
      );

  Map<String, dynamic> toRow() => {'image_url': imageUrl, 'description': description};
}

class AdvertisementProvider with ChangeNotifier {
  List<Advertisement> _advertisements = [];
  List<Advertisement> get advertisements => _advertisements;

  bool isLoading = false;
  String errorMessage = '';

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> fetchAdvertisements() async {
    try {
      isLoading = true;
      errorMessage = '';
      notifyListeners();

      final rows = await _db.from('advertisements').select().order('created_at');
      _advertisements = (rows as List).map((r) => Advertisement.fromRow(r)).toList();

      isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error fetching advertisements: $e');
      isLoading = false;
      errorMessage = 'Failed to load advertisements';
      notifyListeners();
    }
  }

  Future<void> addAdvertisement(String description, File imageFile) async {
    try {
      final path = 'advertisements/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageUrl = await StorageService.uploadFile(Buckets.banners, path, imageFile);

      final advertisement = Advertisement(imageUrl: imageUrl, description: description);
      await _db.from('advertisements').insert(advertisement.toRow());

      _advertisements.add(advertisement);
      notifyListeners();
    } catch (e) {
      print('Error adding advertisement: $e');
    }
  }

  /// The admin screen identifies an ad by its image URL.
  Future<void> deleteAdvertisement(String imageUrl) async {
    try {
      await _db.from('advertisements').delete().eq('image_url', imageUrl);
      _advertisements.removeWhere((ad) => ad.imageUrl == imageUrl);
      notifyListeners();
    } catch (e) {
      print('Error deleting advertisement: $e');
    }
  }
}

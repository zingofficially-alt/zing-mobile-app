import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/Service/StorageService.dart';

class Offer {
  final String id;
  late final String text;
  final String imageUrl;

  Offer({
    required this.id,
    required this.text,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() => {'image_url': imageUrl, 'text': text};

  factory Offer.fromRow(Map<String, dynamic> r) => Offer(
        id: r['id'] ?? '',
        text: r['text'] ?? '',
        imageUrl: r['image_url'] ?? '',
      );
}

class OfferProvider with ChangeNotifier {
  List<Offer> _offers = [];
  bool isLoading = false;

  List<Offer> get offers => _offers;

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> fetchOffers() async {
    try {
      isLoading = true;
      notifyListeners();
      final rows = await _db.from('offers').select().order('created_at');
      _offers = (rows as List).map((r) => Offer.fromRow(r)).toList();
    } catch (e, stackTrace) {
      print('Error fetching offers: $e');
      print('StackTrace: $stackTrace');
      _offers = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addOffer(String text, File? imageFile) async {
    try {
      final row =
          await _db.from('offers').insert({'text': text, 'image_url': ''}).select().single();
      var offer = Offer.fromRow(row);

      if (imageFile != null) {
        final url = await StorageService.uploadFile(
            Buckets.banners, 'offers/${offer.id}.jpg', imageFile);
        await _db.from('offers').update({'image_url': url}).eq('id', offer.id);
        offer = Offer(id: offer.id, imageUrl: url, text: text);
      }

      _offers.add(offer);
      notifyListeners();
    } catch (e) {
      print('Error adding offer: $e');
    }
  }

  Future<void> updateOffer(Offer offer) async {
    try {
      await _db.from('offers').update(offer.toMap()).eq('id', offer.id);
      final index = _offers.indexWhere((o) => o.id == offer.id);
      if (index != -1) {
        _offers[index] = offer;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating offer: $e');
    }
  }

  Future<void> deleteOffer(String id) async {
    try {
      await _db.from('offers').delete().eq('id', id);
      _offers.removeWhere((offer) => offer.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting offer: $e');
    }
  }
}

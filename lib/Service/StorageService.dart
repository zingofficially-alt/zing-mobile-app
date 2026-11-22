import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Buckets created by supabase/migrations/0001_schema.sql.
class Buckets {
  static const store = 'store-images';
  static const product = 'product-images';
  static const profile = 'profile-images';
  static const chat = 'chat-images';
  static const banners = 'banners';
}

class StorageService {
  StorageService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Uploads [file] to [bucket]/[path] (overwriting) and returns its URL.
  /// Public buckets return a public URL; the private chat bucket returns a
  /// long-lived signed URL.
  static Future<String> uploadFile(String bucket, String path, File file) async {
    await _db.storage.from(bucket).upload(path, file,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
    return _urlFor(bucket, path);
  }

  static Future<String> uploadBytes(String bucket, String path, Uint8List bytes,
      {String contentType = 'image/jpeg'}) async {
    await _db.storage.from(bucket).uploadBinary(path, bytes,
        fileOptions: FileOptions(upsert: true, contentType: contentType));
    return _urlFor(bucket, path);
  }

  static Future<void> delete(String bucket, List<String> paths) =>
      _db.storage.from(bucket).remove(paths);

  static Future<String> _urlFor(String bucket, String path) async {
    if (bucket == Buckets.chat) {
      return _db.storage.from(bucket).createSignedUrl(path, 60 * 60 * 24 * 365);
    }
    return _db.storage.from(bucket).getPublicUrl(path);
  }
}

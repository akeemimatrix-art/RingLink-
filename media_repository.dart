import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class MediaRepository {
  MediaRepository(this._client);

  final SupabaseClient _client;

  Future<String> uploadProfileImage(Uint8List bytes, String extension) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You are not signed in.');
    final path = '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('profile-media').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('profile-media').getPublicUrl(path);
  }

  Future<String> uploadVerificationDocument(
    Uint8List bytes,
    String extension,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You are not signed in.');
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('verification-documents').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    return path;
  }
}

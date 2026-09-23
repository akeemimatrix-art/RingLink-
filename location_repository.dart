import 'package:supabase_flutter/supabase_flutter.dart';

class LocationRepository {
  LocationRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listSavedLocations() async {
    final rows = await _client
        .from('saved_locations')
        .select()
        .eq('user_id', _client.auth.currentUser!.id)
        .order('is_favorite', ascending: false)
        .order('label');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addLocation({
    required String label,
    required String addressLabel,
    required double latitude,
    required double longitude,
    bool isFavorite = false,
  }) async {
    await _client.from('saved_locations').insert({
      'user_id': _client.auth.currentUser!.id,
      'label': label.trim(),
      'address_label': addressLabel.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'is_favorite': isFavorite,
    });
  }

  Future<void> deleteLocation(String id) async {
    await _client.from('saved_locations').delete().eq('id', id).eq(
          'user_id',
          _client.auth.currentUser!.id,
        );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

class DirectoryRepository {
  DirectoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> searchProviders({
    required double latitude,
    required double longitude,
    double radiusMeters = 1500,
    String? categoryId,
    String query = '',
    int limit = 30,
  }) async {
    final rows = await _client.rpc('nearby_providers', params: {
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_radius_meters': radiusMeters,
      'p_category_id': categoryId,
      'p_query': query.trim(),
      'p_limit': limit,
    });
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> searchWithoutLocation({
    String query = '',
    String? categoryId,
    int limit = 30,
  }) async {
    List<String>? categoryProviderIds;
    if (categoryId != null) {
      final serviceRows = await _client
          .from('provider_services')
          .select('provider_id')
          .eq('category_id', categoryId);
      categoryProviderIds = serviceRows
          .map((row) => row['provider_id'] as String)
          .toList();
      if (categoryProviderIds.isEmpty) return [];
    }

    var request = _client
        .from('provider_profiles')
        .select('''
          user_id,
          profession,
          years_experience,
          location_label,
          is_available,
          is_verified,
          average_rating,
          total_reviews,
          profiles!provider_profiles_user_id_fkey(display_name, avatar_url, city, phone)
        ''')
        .eq('is_verified', true)
        .eq('is_available', true);

    if (categoryProviderIds != null) {
      request = request.inFilter('user_id', categoryProviderIds);
    }

    if (query.trim().isNotEmpty) {
      final escaped = query.trim().replaceAll(',', '');
      request = request.or(
        'profession.ilike.%$escaped%,location_label.ilike.%$escaped%',
      );
    }

    final rows = await request.order('average_rating', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows).map((row) {
      final profile = row['profiles'] is Map<String, dynamic>
          ? row['profiles'] as Map<String, dynamic>
          : <String, dynamic>{};
      return {
        'provider_id': row['user_id'],
        'display_name': profile['display_name'] ?? 'Provider',
        'avatar_url': profile['avatar_url'],
        'phone': profile['phone'],
        'city': profile['city'],
        'profession': row['profession'],
        'location_label': row['location_label'],
        'is_available': row['is_available'],
        'is_verified': row['is_verified'],
        'average_rating': row['average_rating'],
        'total_reviews': row['total_reviews'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> categories() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> providerDetails(String userId) async {
    final provider = await _client
        .from('provider_profiles')
        .select('''
          user_id,
          profession,
          years_experience,
          location_label,
          is_available,
          is_verified,
          average_rating,
          total_reviews,
          profiles!provider_profiles_user_id_fkey(
            display_name,
            avatar_url,
            bio,
            city,
            gender,
            phone
          )
        ''')
        .eq('user_id', userId)
        .maybeSingle();

    if (provider == null) return null;

    final services = await _client.from('provider_services').select('''
      id,
      service_name,
      category_id,
      categories(name, slug, icon_name)
    ''').eq('provider_id', userId).order('service_name');

    return {
      ...provider,
      'services': List<Map<String, dynamic>>.from(services),
    };
  }
}

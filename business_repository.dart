import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessRepository {
  BusinessRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> myBusiness() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return _client
        .from('business_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> services(String businessId) async {
    final rows = await _client.from('business_services').select('''
      id,
      service_name,
      category_id,
      categories(name, slug, icon_name)
    ''').eq('business_id', businessId).order('service_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> upsertBusiness({
    required String businessName,
    required String description,
    required String phone,
    required String city,
    required String locationLabel,
    required double latitude,
    required double longitude,
    required bool isAvailable,
    required String categoryId,
    List<String> additionalServices = const [],
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You are not signed in.');
    await _client.from('business_profiles').upsert({
      'user_id': userId,
      'business_name': businessName.trim(),
      'description': description.trim(),
      'phone': phone.trim(),
      'city': city.trim(),
      'location_label': locationLabel.trim(),
      'location': 'POINT($longitude $latitude)',
      'is_available': isAvailable,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');

    final serviceNames = <String>{
      businessName.trim(),
      ...additionalServices.map((value) => value.trim()).where((value) => value.isNotEmpty),
    }.where((value) => value.isNotEmpty).toList();

    for (final serviceName in serviceNames) {
      await _client.from('business_services').upsert({
        'business_id': userId,
        'category_id': categoryId,
        'service_name': serviceName,
      }, onConflict: 'business_id,category_id,service_name');
    }
  }

  Future<List<Map<String, dynamic>>> nearbyBusinesses({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
    String? categoryId,
    String query = '',
    int limit = 20,
  }) async {
    final rows = await _client.rpc('nearby_businesses', params: {
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_radius_meters': radiusMeters,
      'p_category_id': categoryId,
      'p_query': query.trim(),
      'p_limit': limit,
    });
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> businessDetails(String id) async {
    final row = await _client
        .from('business_profiles')
        .select()
        .eq('user_id', id)
        .maybeSingle();
    if (row == null) return null;
    final servicesRows = await services(id);
    return {...row, 'services': servicesRows};
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<AppProfile?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return row == null ? null : AppProfile.fromMap(row);
  }

  Future<AppProfile?> getProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : AppProfile.fromMap(row);
  }

  Future<void> updateProfile({
    required String displayName,
    String? phone,
    String? bio,
    String? city,
    String? gender,
    String? avatarUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You are not signed in.');

    await _client.from('profiles').update({
      'display_name': displayName.trim(),
      'phone': phone?.trim(),
      'bio': bio?.trim(),
      'city': city?.trim(),
      'gender': gender,
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> updateRole(AccountRole role) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You are not signed in.');
    await _client.from('profiles').update({
      'account_role': role.dbValue,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  Future<Map<String, dynamic>?> getProviderProfile(String userId) async {
    return _client
        .from('provider_profiles')
        .select('*, profiles!provider_profiles_user_id_fkey(*)')
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<void> upsertProviderProfile({
    required String profession,
    required int yearsExperience,
    required bool isAvailable,
    required double latitude,
    required double longitude,
    required String locationLabel,
    required String categoryId,
    List<String> additionalServices = const [],
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You are not signed in.');

    await _client.from('provider_profiles').upsert({
      'user_id': userId,
      'profession': profession.trim(),
      'years_experience': yearsExperience,
      'is_available': isAvailable,
      'location_label': locationLabel.trim(),
      'location': 'POINT($longitude $latitude)',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');

    final serviceNames = <String>{
      profession.trim(),
      ...additionalServices.map((value) => value.trim()).where((value) => value.isNotEmpty),
    }.where((value) => value.isNotEmpty).toList();

    for (final serviceName in serviceNames) {
      await _client.from('provider_services').upsert({
        'provider_id': userId,
        'category_id': categoryId,
        'service_name': serviceName,
      }, onConflict: 'provider_id,category_id,service_name');
    }
  }

  Future<Map<String, dynamic>?> getMyProvider() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return getProviderProfile(userId);
  }

  Future<List<Map<String, dynamic>>> getProviderServices(String userId) async {
    final rows = await _client.from('provider_services').select('''
      id,
      service_name,
      category_id,
      categories(name, slug, icon_name)
    ''').eq('provider_id', userId).order('service_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> setAvailability(bool available) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You are not signed in.');
    await _client.from('provider_profiles').update({
      'is_available': available,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);
  }
}

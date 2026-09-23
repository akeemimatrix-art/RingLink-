import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class RingRepository {
  RingRepository(this._client);

  final SupabaseClient _client;

  Future<String> createRing({
    required String categoryId,
    required String serviceName,
    required double latitude,
    required double longitude,
    double radiusMeters = 1500,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You are not signed in.');

    final row = await _client.from('ring_requests').insert({
      'customer_id': userId,
      'category_id': categoryId,
      'service_name': serviceName.trim(),
      'radius_meters': radiusMeters,
      'origin': 'POINT($longitude $latitude)',
    }).select('id').single();

    return row['id'] as String;
  }

  Future<Map<String, dynamic>?> getRing(String ringId) async {
    return _client
        .from('ring_requests')
        .select('*, categories(name, slug, icon_name)')
        .eq('id', ringId)
        .maybeSingle();
  }

  Stream<List<Map<String, dynamic>>> watchRingParticipants(String ringId) {
    return _client
        .from('ring_participants')
        .stream(primaryKey: ['ring_id', 'provider_id'])
        .eq('ring_id', ringId)
        .order('created_at')
        .map(List<Map<String, dynamic>>.from);
  }

  Stream<Map<String, dynamic>?> watchRing(String ringId) {
    return _client
        .from('ring_requests')
        .stream(primaryKey: ['id'])
        .eq('id', ringId)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<void> expireRing(String ringId) async {
    await _client.rpc('expire_ring', params: {'p_ring_id': ringId});
  }

  Future<Map<String, dynamic>?> getRingContact(String ringId) async {
    final row = await _client.rpc('get_ring_contact', params: {'p_ring_id': ringId});
    if (row == null) return null;
    if (row is List && row.isNotEmpty) {
      return Map<String, dynamic>.from(row.first as Map);
    }
    if (row is Map<String, dynamic>) return row;
    return null;
  }

  Future<void> cancelRing(String ringId) async {
    await _client.from('ring_requests').update({
      'status': 'cancelled',
    }).eq('id', ringId).eq('customer_id', _client.auth.currentUser!.id);
  }

  Future<void> acceptRing(String ringId) async {
    await _client.from('ring_acceptances').insert({
      'ring_id': ringId,
      'provider_id': _client.auth.currentUser!.id,
    });
  }

  Future<void> declineRing(String ringId) async {
    await _client.from('ring_declines').insert({
      'ring_id': ringId,
      'provider_id': _client.auth.currentUser!.id,
    });
  }

  Future<List<Map<String, dynamic>>> incomingRings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final declined = await _client
        .from('ring_declines')
        .select('ring_id')
        .eq('provider_id', userId);
    final declinedIds = declined.map((e) => e['ring_id'] as String).toList();

    final rows = await _client.from('ring_participants').select('''
      ring_id,
      provider_id,
      status,
      created_at,
      ring_requests!ring_participants_ring_id_fkey(
        id,
        customer_id,
        category_id,
        service_name,
        radius_meters,
        status,
        created_at,
        expires_at,
        categories(name, slug, icon_name)
      )
    ''').eq('provider_id', userId).eq('status', 'ringing').order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows).where((row) {
      final ringId = row['ring_id'] as String?;
      final request = row['ring_requests'];
      final requestMap = request is Map<String, dynamic>
          ? request
          : <String, dynamic>{};
      final requestStatus = requestMap['status'] as String?;
      final expiresAt = DateTime.tryParse(requestMap['expires_at']?.toString() ?? '');
      final active = requestStatus == 'ringing' &&
          (expiresAt == null || expiresAt.isAfter(DateTime.now().toUtc()));
      return active && !declinedIds.contains(ringId);
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchIncomingRings() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client
        .from('ring_participants')
        .stream(primaryKey: ['ring_id', 'provider_id'])
        .eq('provider_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((row) => row['status'] == 'ringing')
            .map(Map<String, dynamic>.from)
            .toList());
  }

  Future<List<Map<String, dynamic>>> ringHistory() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final customerRings = await _client.from('ring_requests').select('''
      id,
      customer_id,
      service_name,
      status,
      created_at,
      expires_at,
      winner_provider_id,
      categories(name)
    ''').eq('customer_id', userId).order('created_at', ascending: false).limit(50);

    final providerRings = await _client.from('ring_participants').select('''
      ring_id,
      provider_id,
      status,
      created_at,
      ring_requests!ring_participants_ring_id_fkey(
        id,
        customer_id,
        service_name,
        status,
        created_at,
        winner_provider_id,
        categories(name)
      )
    ''').eq('provider_id', userId).order('created_at', ascending: false).limit(50);

    return [
      ...List<Map<String, dynamic>>.from(customerRings).map((e) => {
            ...e,
            'direction': 'outgoing',
          }),
      ...List<Map<String, dynamic>>.from(providerRings).map((e) => {
            ...e,
            'direction': 'incoming',
          }),
    ]..sort((a, b) {
        final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return bd.compareTo(ad);
      });
  }
}

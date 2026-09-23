import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewRepository {
  ReviewRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> providerReviews(String providerId) async {
    final rows = await _client.from('reviews').select('''
      id,
      rating,
      comment,
      created_at,
      customer_id,
      profiles!reviews_customer_id_fkey(display_name, avatar_url)
    ''').eq('provider_id', providerId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addReview({
    required String providerId,
    required int rating,
    required String comment,
    String? ringId,
  }) async {
    await _client.from('reviews').insert({
      'customer_id': _client.auth.currentUser!.id,
      'provider_id': providerId,
      'ring_id': ringId,
      'rating': rating,
      'comment': comment.trim(),
    });
  }
}

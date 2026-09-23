import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  Future<String> getOrCreateConversation(String providerId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You are not signed in.');
    final row = await _client.rpc('get_or_create_conversation', params: {
      'p_provider_id': providerId,
    });
    return row as String;
  }

  Future<Map<String, dynamic>?> conversation(String id) async {
    return _client
        .from('conversations')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map(List<Map<String, dynamic>>.from);
  }

  Future<void> sendText(String conversationId, String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _client.auth.currentUser!.id,
      'message_type': 'text',
      'body': body,
    });
    await _client.from('conversations').update({
      'last_message_preview': body.length > 120 ? '${body.substring(0, 120)}…' : body,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', conversationId);
  }
}

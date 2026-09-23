import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/formatters.dart';
import '../../repositories/chat_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.avatarUrl,
  });

  final String conversationId;
  final String title;
  final String? avatarUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatRepository _chat;
  final _messageController = TextEditingController();
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _chat = ChatRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    try {
      final messages = await _chat.messages(widget.conversationId);
      if (mounted) setState(() => _messages = messages);
      _subscription = _chat.watchMessages(widget.conversationId).listen((rows) {
        if (mounted) setState(() => _messages = rows);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load chat: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _messageController.clear();
    try {
      await _chat.sendText(widget.conversationId, text);
    } catch (error) {
      if (mounted) {
        _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.avatarUrl == null
                  ? null
                  : NetworkImage(widget.avatarUrl!),
              child: widget.avatarUrl == null
                  ? const Icon(Icons.person_outline, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(widget.title),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Start the conversation. Keep it clear and respectful.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final mine = message['sender_id'] == currentUserId;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message['body'] as String? ?? ''),
                                  const SizedBox(height: 4),
                                  Text(
                                    Formatters.time(message['created_at']),
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
